import SwiftUI

struct TaskListView: View {
    enum FocusField: Hashable {
        case task(UUID)
        case scrollView
    }

    @State private var store: TaskStore
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TaskItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true),
        ],
        animation: .default
    )
    private var tasks: FetchedResults<TaskItem>
    @FocusState private var focusedField: FocusField?
    @State private var selectedTaskID: UUID?
    @State private var refreshID = UUID()
    @State private var draggedTaskID: UUID?
    @State private var visualOrder: [UUID]?
    @State private var pendingFocus: FocusField?

    init(store: TaskStore = TaskStore()) {
        _store = State(wrappedValue: store)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(displayActiveTasks) { task in
                    let taskID = task.id
                    TaskRowView(
                        task: task,
                        taskID: taskID,
                        isSelected: selectedTaskID == taskID,
                        isEditing: editingTaskID == taskID,
                        focusedField: $focusedField,
                        onToggle: toggleCompletion(_:),
                        onTitleChange: updateTitle(_:_:),
                        onDelete: deleteTask(_:),
                        onSelect: selectTask(_:),
                        onStartEdit: startEditing(_:),
                        onEndEdit: endEditing(_:shouldCreateNewTask:)
                    )
                    .taskDragGesture(
                        isActive: !task.isCompleted,
                        taskID: task.id,
                        onDragStart: { startDrag(taskID: task.id) }
                    )
                    .overlay {
                        if draggedTaskID != nil && draggedTaskID != task.id {
                            VStack(spacing: 0) {
                                // Top 1/6 - insert BEFORE
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(1)
                                    .dropDestination(for: String.self, action: { _, _ in false }, isTargeted: { isTargeted in
                                        if isTargeted {
                                            updateVisualOrder(insertBefore: task.id)
                                        }
                                    })

                                // Middle 2/3 - insert based on direction
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(4)
                                    .dropDestination(for: String.self, action: { _, _ in false }, isTargeted: { isTargeted in
                                        if isTargeted {
                                            updateVisualOrderSmart(relativeTo: task.id)
                                        }
                                    })

                                // Bottom 1/6 - insert AFTER
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(1)
                                    .dropDestination(for: String.self, action: { _, _ in false }, isTargeted: { isTargeted in
                                        if isTargeted {
                                            updateVisualOrder(insertAfter: task.id)
                                        }
                                    })
                            }
                        }
                    }
                }

                // Drop zone at the end
                if !activeTasks.isEmpty && draggedTaskID != nil {
                    Color.clear
                        .frame(height: 44)
                        .dropDestination(for: String.self, action: { _, _ in false }, isTargeted: { isTargeted in
                            if isTargeted {
                                updateVisualOrder(insertAtEnd: true)
                            }
                        })
                }

                ForEach(completedTasks) { task in
                    let taskID = task.id
                    TaskRowView(
                        task: task,
                        taskID: taskID,
                        isSelected: selectedTaskID == taskID,
                        isEditing: editingTaskID == taskID,
                        focusedField: $focusedField,
                        onToggle: toggleCompletion(_:),
                        onTitleChange: updateTitle(_:_:),
                        onDelete: deleteTask(_:),
                        onSelect: selectTask(_:),
                        onStartEdit: startEditing(_:),
                        onEndEdit: endEditing(_:shouldCreateNewTask:)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .dropDestination(for: String.self) { items, location in
                handleDrop(items: items)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleBackgroundTap()
        }
        .focusable()
        .focused($focusedField, equals: .scrollView)
        .focusEffectDisabled()
        .accessibilityIdentifier("task-list-scrollview")
        .keyboardNavigation(
            onUpArrow: navigateUp,
            onDownArrow: navigateDown,
            onSpace: toggleSelectedTask,
            onReturn: focusSelectedTask
        )
        .onAppear {
            // Set initial focus to enable keyboard navigation
            if focusedField == nil {
                focusedField = .scrollView
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            handleFocusChange(from: oldValue, to: newValue)

            // Focus repair/resolution: when focus becomes nil, either resolve pending focus or repair to scrollView
            if newValue == nil {
                if let pending = pendingFocus {
                    print("🟣 onChange resolving pendingFocus: \(pending)")
                    focusedField = pending
                    pendingFocus = nil
                } else {
                    print("🟣 onChange repairing nil focus to .scrollView")
                    focusedField = .scrollView
                }
            }
        }
    }

    private var activeTasks: [TaskItem] {
        Array(tasks.filter { !$0.isCompleted })
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var displayActiveTasks: [TaskItem] {
        guard let visualOrder = visualOrder else {
            return activeTasks
        }

        return visualOrder.compactMap { id in
            activeTasks.first(where: { $0.id == id })
        }
    }

    private var completedTasks: [TaskItem] {
        Array(tasks.filter { $0.isCompleted })
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var allTasksInDisplayOrder: [TaskItem] {
        displayActiveTasks + completedTasks
    }

    private var editingTaskID: UUID? {
        if case .task(let id) = focusedField {
            return id
        }
        return nil
    }

    private func isLastActiveTask(_ taskID: UUID) -> Bool {
        guard let lastTask = activeTasks.last else { return false }
        return lastTask.id == taskID
    }

    private func createTaskAndFocus() {
        // Clear any lingering drag state
        draggedTaskID = nil
        visualOrder = nil

        // Create Core Data task (Core Data assigns the ID)
        let task = store.createTask(title: "")

        // Record intent to focus the new task
        // This will be resolved in onChange(of: tasks) after view is created
        pendingFocus = .task(task.id)
        selectedTaskID = task.id
    }

    private func handleBackgroundTap() {
        // Check if a task is focused (not just scrollView)
        let isTaskFocused = if case .task = focusedField { true } else { false }

        if isTaskFocused || selectedTaskID != nil {
            selectedTaskID = nil
            // Focus repair will set to .scrollView if needed
        } else {
            createTaskAndFocus()
            // Trigger focus resolution by setting to nil
            // onChange(of: focusedField) will then resolve pendingFocus
            focusedField = nil
        }
    }

    private func handleFocusChange(from oldValue: FocusField?, to newValue: FocusField?) {
        print("🟣 handleFocusChange() from: \(String(describing: oldValue)) to: \(String(describing: newValue))")
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
        guard case let .task(id) = field else { return nil }
        return id
    }

    private func deleteIfEmpty(taskID: UUID) {
        // Don't delete if this is the pending focus target
        if case .task(let pendingTaskID) = pendingFocus, pendingTaskID == taskID {
            print("🔴 deleteIfEmpty() skipping - task is pending focus")
            return
        }

        guard let task = tasks.first(where: { $0.id == taskID }) else {
            return
        }
        let trimmedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty else { return }
        deleteTask(task)
    }


    private func updateTitle(_ task: TaskItem, _ title: String) {
        guard task.title != title else { return }
        store.updateWithoutSaving(taskID: task.id, title: title)
    }

    private func toggleCompletion(_ task: TaskItem) {
        if task.isCompleted {
            store.uncomplete(taskID: task.id)
        } else {
            store.complete(taskID: task.id)
        }
    }

    private func selectTask(_ taskID: UUID) {
        selectedTaskID = taskID
    }

    private func deleteTask(_ task: TaskItem) {
        let taskID = task.id
        print("🔴 deleteTask() called for task \(taskID)")

        // Clear selection if this task was selected
        if selectedTaskID == taskID {
            print("🔴 deleteTask() clearing selectedTaskID")
            selectedTaskID = nil
        }

        store.delete(taskID: taskID)
        print("🔴 deleteTask() completed")
    }

    private func navigateUp() -> KeyPress.Result {
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

    private func navigateDown() -> KeyPress.Result {
        print("⬇️ navigateDown() called, focusedField: \(String(describing: focusedField))")
        guard focusedField == .scrollView else {
            print("⬇️ navigateDown() IGNORED - focus is not .scrollView")
            return .ignored
        }

        guard let currentID = selectedTaskID else {
            selectedTaskID = completedTasks.first?.id ?? activeTasks.first?.id
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

    private func toggleSelectedTask() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }
        guard let currentID = selectedTaskID else { return .handled }
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else { return .handled }
        toggleCompletion(task)
        return .handled
    }

    private func focusSelectedTask() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }
        guard let currentID = selectedTaskID else { return .handled }
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else { return .handled }
        guard !task.isCompleted else { return .handled }
        startEditing(currentID)
        return .handled
    }


    // MARK: - Focus Management

    private func focusTextField(_ taskID: UUID) {
        focusedField = .task(taskID)
    }

    private func startEditing(_ taskID: UUID) {
        print("🟢 startEditing called for task \(taskID)")
        selectedTaskID = taskID
        focusedField = .task(taskID)
        print("🟢 startEditing set focusedField = .task(\(taskID))")
    }

    private func endEditing(_ taskID: UUID, shouldCreateNewTask: Bool) {
        print("🟢 endEditing() called for task \(taskID), shouldCreateNewTask: \(shouldCreateNewTask)")
        // Save any pending changes
        store.save()

        // Check conditions BEFORE deleting the task
        let wasLastActiveTask = isLastActiveTask(taskID)
        let willBeDeleted = shouldDeleteIfEmpty(taskID: taskID)
        print("🟢 endEditing() wasLastActiveTask: \(wasLastActiveTask), willBeDeleted: \(willBeDeleted)")

        if willBeDeleted {
            print("🟢 endEditing() deleting task - focus will be repaired automatically by onChange")
            selectedTaskID = nil
            deleteIfEmpty(taskID: taskID)
            // No explicit focus management - onChange will repair to .scrollView
        } else if wasLastActiveTask && shouldCreateNewTask {
            print("🟢 endEditing() creating new task")
            createTaskAndFocus()
        } else {
            print("🟢 endEditing() keeping task selected, returning to navigation")
            selectedTaskID = taskID
            // Focus repair will set to .scrollView if needed
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

    private func startDrag(taskID: UUID) {
        draggedTaskID = taskID
        visualOrder = activeTasks.map(\.id)
    }

    private func updateVisualOrder(insertBefore targetID: UUID) {
        guard let draggedID = draggedTaskID,
              let order = visualOrder else { return }

        var newOrder = order.filter { $0 != draggedID }
        if let targetIndex = newOrder.firstIndex(of: targetID) {
            newOrder.insert(draggedID, at: targetIndex)
        }

        if newOrder != visualOrder {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                visualOrder = newOrder
            }
        }
    }

    private func updateVisualOrder(insertAfter targetID: UUID) {
        guard let draggedID = draggedTaskID,
              let order = visualOrder else { return }

        var newOrder = order.filter { $0 != draggedID }
        if let targetIndex = newOrder.firstIndex(of: targetID) {
            newOrder.insert(draggedID, at: targetIndex + 1)
        }

        if newOrder != visualOrder {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                visualOrder = newOrder
            }
        }
    }

    private func updateVisualOrderSmart(relativeTo targetID: UUID) {
        guard let draggedID = draggedTaskID,
              let order = visualOrder else { return }

        // Determine if dragged item is currently above or below target
        guard let draggedIndex = order.firstIndex(of: draggedID),
              let targetIndex = order.firstIndex(of: targetID) else { return }

        if draggedIndex < targetIndex {
            // Dragging from above → insert after target
            updateVisualOrder(insertAfter: targetID)
        } else {
            // Dragging from below → insert before target
            updateVisualOrder(insertBefore: targetID)
        }
    }

    private func updateVisualOrder(insertAtEnd: Bool) {
        guard let draggedID = draggedTaskID,
              let order = visualOrder else { return }

        var newOrder = order.filter { $0 != draggedID }
        newOrder.append(draggedID)

        if newOrder != visualOrder {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                visualOrder = newOrder
            }
        }
    }

    private func handleDrop(items: [String]) -> Bool {
        guard let droppedUUIDString = items.first,
              let droppedUUID = UUID(uuidString: droppedUUIDString),
              let order = visualOrder,
              let finalIndex = order.firstIndex(of: droppedUUID) else {
            draggedTaskID = nil
            visualOrder = nil
            return false
        }

        // Commit the reorder
        store.moveTask(taskID: droppedUUID, toIndex: finalIndex)

        // Clear drag state
        draggedTaskID = nil
        visualOrder = nil

        return true
    }
}
