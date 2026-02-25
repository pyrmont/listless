import SwiftUI

extension TaskListView {

    // MARK: - Computed Properties

    var activeTasks: [TaskItem] {
        Array(tasks.filter { !$0.isCompleted })
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var displayActiveTasks: [TaskItem] {
        guard let visualOrder else {
            return activeTasks
        }

        return visualOrder.compactMap { id in
            activeTasks.first(where: { $0.id == id })
        }
    }

    var completedTasks: [TaskItem] {
        Array(tasks.filter { $0.isCompleted })
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var allTasksInDisplayOrder: [TaskItem] {
        displayActiveTasks + completedTasks
    }

    var editingTaskID: UUID? {
        if case .task(let id) = focusedField {
            return id
        }
        return nil
    }

    var draggedTaskID: UUID? {
        if case .dragging(let id, _) = dragState {
            return id
        }
        return nil
    }

    var visualOrder: [UUID]? {
        if case .dragging(_, let order) = dragState {
            return order
        }
        return nil
    }

    func presentStoreError(_ error: Error) {
        syncMonitor.ingest(error: error)
    }

    private func isLastActiveTask(_ taskID: UUID) -> Bool {
        guard let lastTask = activeTasks.last else { return false }
        return lastTask.id == taskID
    }

    // MARK: - Task Creation

    func createNewTaskAtTop() -> UUID {
        clearDragState()
        do {
            let task = try store.createTask(title: "", atBeginning: true)
            pendingFocus = .task(task.id)
            focusedField = .task(task.id)
            selectedTaskID = task.id
            return task.id
        } catch {
            presentStoreError(error)
            return UUID()
        }
    }

    func createNewTask() {
        clearDragState()
        do {
            let task = try store.createTask(title: "")
            pendingFocus = .task(task.id)
            focusedField = .task(task.id)
            selectedTaskID = task.id
        } catch {
            presentStoreError(error)
        }
    }

    func createTask(title: String, afterTaskID: UUID) {
        clearDragState()
        do {
            let sortOrder = try sortOrderAfter(taskID: afterTaskID)
            let newTask = try store.createTask(title: title, sortOrder: sortOrder)
            selectedTaskID = newTask.id
            focusedField = .scrollView
        } catch {
            presentStoreError(error)
        }
    }

    private func sortOrderAfter(taskID: UUID) throws -> Int64? {
        guard let afterIndex = activeTasks.firstIndex(where: { $0.id == taskID }) else {
            return nil
        }
        let afterTask = activeTasks[afterIndex]
        if afterIndex + 1 < activeTasks.count {
            let nextTask = activeTasks[afterIndex + 1]
            let midpoint = (afterTask.sortOrder + nextTask.sortOrder) / 2
            if midpoint == afterTask.sortOrder {
                // Consecutive sort orders leave no room; re-normalise with 1000-unit gaps
                // then recompute. Core Data's identity map ensures afterTask/nextTask reflect
                // the updated values immediately after normalisation.
                try store.normalizeSortOrders()
                return (afterTask.sortOrder + nextTask.sortOrder) / 2
            }
            return midpoint
        } else {
            return afterTask.sortOrder + 1000
        }
    }

    // MARK: - Interaction Handlers

    func handleBackgroundTap() {
        let isTaskFocused = if case .task = focusedField { true } else { false }

        if isTaskFocused || selectedTaskID != nil {
            selectedTaskID = nil
            focusedField = nil
        } else {
            createNewTask()
            focusedField = nil
        }
    }

    func handleFocusChange(from oldValue: FocusField?, to newValue: FocusField?) {
        let oldID = taskID(from: oldValue)
        let newID = taskID(from: newValue)

        guard oldID != newID, let oldID else {
            return
        }
        deleteIfEmpty(taskID: oldID)
    }

    private func taskID(from field: FocusField?) -> UUID? {
        guard case .task(let id) = field else { return nil }
        return id
    }

    private func deleteIfEmpty(taskID: UUID) {
        if case .task(let pendingTaskID) = pendingFocus, pendingTaskID == taskID {
            return
        }

        guard let task = tasks.first(where: { $0.id == taskID }) else {
            return
        }
        let trimmedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty else { return }

        managedObjectContext.undoManager?.removeAllActions(withTarget: task)
        managedObjectContext.undoManager?.disableUndoRegistration()
        deleteTask(task)
        managedObjectContext.undoManager?.enableUndoRegistration()
    }

    func updateTitle(_ task: TaskItem, _ title: String) {
        guard task.title != title else { return }
        do {
            try store.updateWithoutSaving(taskID: task.id, title: title)
        } catch {
            presentStoreError(error)
        }
    }

    func toggleCompletion(_ task: TaskItem) {
        do {
            if task.isCompleted {
                try store.uncomplete(taskID: task.id)
            } else {
                try store.complete(taskID: task.id)
            }
        } catch {
            presentStoreError(error)
        }
    }

    func handleSwipeComplete(_ taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        toggleCompletion(task)
    }

    func handleSwipeDelete(_ taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        deleteTask(task)
    }

    func selectTask(_ taskID: UUID) {
        selectedTaskID = taskID
    }

    func deleteTask(_ task: TaskItem) {
        let taskID = task.id
        do {
            try store.delete(taskID: taskID)
            if selectedTaskID == taskID {
                selectedTaskID = nil
            }
        } catch {
            presentStoreError(error)
        }
    }

    func clearCompletedTasks() {
        for task in completedTasks.reversed() {
            do {
                try store.delete(taskID: task.id)
            } catch {
                presentStoreError(error)
            }
        }
    }

    // MARK: - Keyboard Navigation

    func navigateUp() -> KeyPress.Result {
        guard focusedField == .scrollView else {
            return .ignored
        }

        guard let currentID = selectedTaskID else {
            selectedTaskID = activeTasks.last?.id
            return .handled
        }

        let displayOrder = allTasksInDisplayOrder
        guard let currentIndex = displayOrder.firstIndex(where: { $0.id == currentID }) else {
            return .handled
        }

        if currentIndex > 0 {
            selectedTaskID = displayOrder[currentIndex - 1].id
        }
        return .handled
    }

    func navigateDown() -> KeyPress.Result {
        guard focusedField == .scrollView else {
            return .ignored
        }

        guard let currentID = selectedTaskID else {
            selectedTaskID = activeTasks.first?.id ?? completedTasks.first?.id
            return .handled
        }

        let displayOrder = allTasksInDisplayOrder
        guard let currentIndex = displayOrder.firstIndex(where: { $0.id == currentID }) else {
            return .handled
        }

        if currentIndex < displayOrder.count - 1 {
            selectedTaskID = displayOrder[currentIndex + 1].id
        }
        return .handled
    }

    func toggleSelectedTask() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }
        guard let currentID = selectedTaskID else { return .handled }
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else {
            return .handled
        }
        toggleCompletion(task)
        return .handled
    }

    func focusSelectedTask() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }
        guard let currentID = selectedTaskID else { return .handled }
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else {
            return .handled
        }
        guard !task.isCompleted else { return .handled }
        startEditing(currentID)
        return .handled
    }

    func deleteSelectedTask() -> KeyPress.Result {
        guard focusedField == .scrollView else {
            return .ignored
        }
        guard let currentID = selectedTaskID else {
            return .handled
        }
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else {
            return .handled
        }
        deleteTask(task)
        return .handled
    }

    func moveSelectedTaskUp() {
        guard focusedField == .scrollView else { return }
        guard let currentID = selectedTaskID else { return }
        guard let currentIndex = activeTasks.firstIndex(where: { $0.id == currentID }) else { return }
        guard currentIndex > 0 else { return }

        do {
            try store.moveTask(taskID: currentID, toIndex: currentIndex - 1)
        } catch {
            presentStoreError(error)
        }
    }

    func moveSelectedTaskDown() {
        guard focusedField == .scrollView else { return }
        guard let currentID = selectedTaskID else { return }
        guard let currentIndex = activeTasks.firstIndex(where: { $0.id == currentID }) else { return }
        guard currentIndex < activeTasks.count - 1 else { return }

        do {
            try store.moveTask(taskID: currentID, toIndex: currentIndex + 1)
        } catch {
            presentStoreError(error)
        }
    }

    func markSelectedTaskCompleted() {
        guard focusedField == .scrollView else { return }
        guard let currentID = selectedTaskID else { return }
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else { return }
        toggleCompletion(task)
    }

    // MARK: - Focus Management

    func focusTextField(_ taskID: UUID) {
        focusedField = .task(taskID)
    }

    func startEditing(_ taskID: UUID) {
        selectedTaskID = taskID
        focusedField = .task(taskID)
        pendingFocus = nil
    }

    func endEditing(_ taskID: UUID, shouldCreateNewTask: Bool) {
        do {
            try store.save()
        } catch {
            presentStoreError(error)
        }

        let wasLastActiveTask = isLastActiveTask(taskID)
        let willBeDeleted = shouldDeleteIfEmpty(taskID: taskID)

        if willBeDeleted {
            selectedTaskID = nil
            deleteIfEmpty(taskID: taskID)
        } else if wasLastActiveTask && shouldCreateNewTask {
            createNewTask()
        } else if shouldCreateNewTask {
            focusedField = .scrollView
        }
    }

    private func shouldDeleteIfEmpty(taskID: UUID) -> Bool {
        guard let task = tasks.first(where: { $0.id == taskID }) else {
            return false
        }
        let trimmedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty
    }

    // MARK: - Drag and Drop

    func startDrag(taskID: UUID) {
        guard case .idle = dragState else { return }
        dragState = .dragging(id: taskID, order: activeTasks.map(\.id))
        didStartDrag()
    }

    func updateVisualOrder(insertBefore targetID: UUID) {
        guard let draggedID = draggedTaskID,
            let order = visualOrder
        else { return }

        var newOrder = order.filter { $0 != draggedID }
        if let targetIndex = newOrder.firstIndex(of: targetID) {
            newOrder.insert(draggedID, at: targetIndex)
        }

        if newOrder != order {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                setDragOrder(newOrder)
            }
        }
    }

    func updateVisualOrder(insertAfter targetID: UUID) {
        guard let draggedID = draggedTaskID,
            let order = visualOrder
        else { return }

        var newOrder = order.filter { $0 != draggedID }
        if let targetIndex = newOrder.firstIndex(of: targetID) {
            newOrder.insert(draggedID, at: targetIndex + 1)
        }

        if newOrder != order {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                setDragOrder(newOrder)
            }
        }
    }

    func updateVisualOrderSmart(relativeTo targetID: UUID) {
        guard let draggedID = draggedTaskID,
            let order = visualOrder
        else { return }

        guard let draggedIndex = order.firstIndex(of: draggedID),
            let targetIndex = order.firstIndex(of: targetID)
        else { return }

        if draggedIndex < targetIndex {
            updateVisualOrder(insertAfter: targetID)
        } else {
            updateVisualOrder(insertBefore: targetID)
        }
    }

    func updateVisualOrder(insertAtEnd: Bool) {
        guard let draggedID = draggedTaskID,
            let order = visualOrder
        else { return }

        var newOrder = order.filter { $0 != draggedID }
        newOrder.append(draggedID)

        if newOrder != order {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                setDragOrder(newOrder)
            }
        }
    }

    func commitCurrentDrag() -> Bool {
        guard let droppedUUID = draggedTaskID,
            let order = visualOrder,
            let finalIndex = order.firstIndex(of: droppedUUID)
        else {
            clearDragState()
            return false
        }

        do {
            try store.moveTask(taskID: droppedUUID, toIndex: finalIndex)
            clearDragState()
        } catch {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                clearDragState()
            }
            presentStoreError(error)
        }

        return true
    }

    func setDragOrder(_ order: [UUID]) {
        guard case .dragging(let id, _) = dragState else { return }
        dragState = .dragging(id: id, order: order)
    }

    func clearDragState() {
        dragState = .idle
    }
}
