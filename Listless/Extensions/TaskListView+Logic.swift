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
        print(
            "🟣 handleFocusChange() from: \(String(describing: oldValue)) to: \(String(describing: newValue))"
        )
        let oldID = taskID(from: oldValue)
        let newID = taskID(from: newValue)

        guard oldID != newID, let oldID else {
            print("🟣 handleFocusChange() no action needed")
            return
        }
        print("🟣 handleFocusChange() calling deleteIfEmpty for task \(oldID)")
        deleteIfEmpty(taskID: oldID)
    }

    private func taskID(from field: FocusField?) -> UUID? {
        guard case .task(let id) = field else { return nil }
        return id
    }

    private func deleteIfEmpty(taskID: UUID) {
        if case .task(let pendingTaskID) = pendingFocus, pendingTaskID == taskID {
            print("🔴 deleteIfEmpty() skipping - task is pending focus")
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
        print("🔴 deleteTask() called for task \(taskID)")
        do {
            try store.delete(taskID: taskID)
            if selectedTaskID == taskID {
                print("🔴 deleteTask() clearing selectedTaskID")
                selectedTaskID = nil
            }
            print("🔴 deleteTask() completed")
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
        print("⬆️ navigateUp() called, focusedField: \(String(describing: focusedField))")
        guard focusedField == .scrollView else {
            print("⬆️ navigateUp() IGNORED - focus is not .scrollView")
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
        print("⬇️ navigateDown() called, focusedField: \(String(describing: focusedField))")
        guard focusedField == .scrollView else {
            print("⬇️ navigateDown() IGNORED - focus is not .scrollView")
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
        print("🗑️ deleteSelectedTask() called, focusedField: \(String(describing: focusedField))")
        guard focusedField == .scrollView else {
            print("🗑️ deleteSelectedTask() IGNORED - focus is not .scrollView")
            return .ignored
        }
        guard let currentID = selectedTaskID else {
            print("🗑️ deleteSelectedTask() no task selected")
            return .handled
        }
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else {
            print("🗑️ deleteSelectedTask() task not found")
            return .handled
        }
        print("🗑️ deleteSelectedTask() deleting task \(currentID)")
        deleteTask(task)
        return .handled
    }

    // MARK: - Focus Management

    func focusTextField(_ taskID: UUID) {
        focusedField = .task(taskID)
    }

    func startEditing(_ taskID: UUID) {
        print("🟢 startEditing called for task \(taskID)")
        selectedTaskID = taskID
        focusedField = .task(taskID)
        pendingFocus = nil
        print("🟢 startEditing set focusedField = .task(\(taskID))")
    }

    func endEditing(_ taskID: UUID, shouldCreateNewTask: Bool) {
        print(
            "🟢 endEditing() called for task \(taskID), shouldCreateNewTask: \(shouldCreateNewTask)"
        )
        do {
            try store.save()
        } catch {
            presentStoreError(error)
        }

        let wasLastActiveTask = isLastActiveTask(taskID)
        let willBeDeleted = shouldDeleteIfEmpty(taskID: taskID)
        print(
            "🟢 endEditing() wasLastActiveTask: \(wasLastActiveTask), willBeDeleted: \(willBeDeleted)"
        )

        if willBeDeleted {
            print("🟢 endEditing() deleting task - focus will be repaired automatically by onChange")
            selectedTaskID = nil
            deleteIfEmpty(taskID: taskID)
        } else if wasLastActiveTask && shouldCreateNewTask {
            print("🟢 endEditing() creating new task")
            createNewTask()
        } else if shouldCreateNewTask {
            print("🟢 endEditing() Return on non-last task — dismiss keyboard, enter navigation mode")
            focusedField = .scrollView
        } else {
            print("🟢 endEditing() done, selection unchanged")
        }

        print("🟢 endEditing() completed, final focus: \(String(describing: focusedField))")
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

    func handleDrop(items: [String]) -> Bool {
        guard let droppedUUIDString = items.first,
            let droppedUUID = UUID(uuidString: droppedUUIDString),
            let order = visualOrder,
            let finalIndex = order.firstIndex(of: droppedUUID)
        else {
            clearDragState()
            return false
        }

        do {
            try store.moveTask(taskID: droppedUUID, toIndex: finalIndex)
        } catch {
            presentStoreError(error)
        }
        clearDragState()

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
