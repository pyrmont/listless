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
    @State private var editingTaskID: UUID?
    @State private var justCreatedTaskID: UUID?

    init(store: TaskStore = TaskStore()) {
        _store = State(wrappedValue: store)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !completedTasks.isEmpty {
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)
                        .padding(.bottom, 6)
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
                        onSubmit: handleSubmit(_:),
                        onTitleChange: updateTitle(_:_:),
                        onDelete: deleteTask(_:),
                        onSelect: { selectTask(taskID) },
                        onStartEdit: { startEditing(taskID) },
                        onEndEdit: { endEditing(taskID) }
                    )
                }

                if !activeTasks.isEmpty && !completedTasks.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                }

                ForEach(displayActiveTasks) { task in
                    let taskID = task.id
                    TaskRowView(
                        task: task,
                        taskID: taskID,
                        isSelected: selectedTaskID == taskID,
                        isEditing: editingTaskID == taskID,
                        focusedField: $focusedField,
                        onToggle: toggleCompletion(_:),
                        onSubmit: handleSubmit(_:),
                        onTitleChange: updateTitle(_:_:),
                        onDelete: deleteTask(_:),
                        onSelect: { selectTask(taskID) },
                        onStartEdit: { startEditing(taskID) },
                        onEndEdit: { endEditing(taskID) }
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
            onReturn: focusSelectedTask,
            onEscape: unfocusTextField
        )
        .onAppear {
            focusScrollView()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            handleFocusChange(from: oldValue, to: newValue)
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
        completedTasks + displayActiveTasks
    }

    private func createTaskAndFocus() {
        // Clear any lingering drag state
        draggedTaskID = nil
        visualOrder = nil

        // Create Core Data task
        let task = store.createTask(title: "")

        // Protect from immediate deletion
        justCreatedTaskID = task.id
        selectedTaskID = task.id

        // Set editing state to trigger TextField render
        editingTaskID = task.id

        // Wait for view to update, then focus the TextField
        DispatchQueue.main.async {
            self.focusedField = .task(task.id)
            // Clear the just-created protection once focused
            self.justCreatedTaskID = nil
        }
    }

    private func handleBackgroundTap() {
        // Check if a task is focused (not just scrollView)
        let isTaskFocused = if case .task = focusedField { true } else { false }

        if isTaskFocused || selectedTaskID != nil {
            focusScrollView()
            selectedTaskID = nil
        } else {
            createTaskAndFocus()
        }
    }

    private func handleFocusChange(from oldValue: FocusField?, to newValue: FocusField?) {
        let oldID = taskID(from: oldValue)
        let newID = taskID(from: newValue)

        guard oldID != newID, let oldID else { return }
        deleteIfEmpty(taskID: oldID)
    }

    private func taskID(from field: FocusField?) -> UUID? {
        guard case let .task(id) = field else { return nil }
        return id
    }

    private func deleteIfEmpty(taskID: UUID) {
        // Don't delete tasks that were just created
        if taskID == justCreatedTaskID {
            return
        }

        guard let task = tasks.first(where: { $0.id == taskID }) else {
            return
        }
        let trimmedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty else { return }
        deleteTask(task)
    }

    private func handleSubmit(_ task: TaskItem) {
        createTaskAndFocus()
    }

    private func updateTitle(_ task: TaskItem, _ title: String) {
        guard task.title != title else { return }
        store.update(taskID: task.id, title: title)

        // Clear the justCreated flag once user starts typing
        if task.id == justCreatedTaskID && !title.isEmpty {
            justCreatedTaskID = nil
        }
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
        if focusedField == .task(taskID) {
            focusScrollView()
        }
        if selectedTaskID == taskID {
            selectedTaskID = nil
        }
        store.delete(taskID: taskID)
    }

    private func navigateUp() -> KeyPress.Result {
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

    private func navigateDown() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }

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

    private func unfocusTextField() -> KeyPress.Result {
        guard case .task = focusedField else {
            return .ignored
        }
        if let editingID = editingTaskID {
            endEditing(editingID)
        }
        focusScrollView()
        return .handled
    }

    // MARK: - Focus Management

    private func focusScrollView() {
        // Try clearing focus first, then setting to scrollView
        focusedField = nil
        DispatchQueue.main.async {
            self.focusedField = .scrollView
        }
    }

    private func focusTextField(_ taskID: UUID) {
        focusedField = .task(taskID)
    }

    private func startEditing(_ taskID: UUID) {
        editingTaskID = taskID
        focusedField = .task(taskID)
    }

    private func endEditing(_ taskID: UUID) {
        // Only clear editingTaskID if it matches this task
        guard editingTaskID == taskID else {
            return
        }

        deleteIfEmpty(taskID: taskID)
        editingTaskID = nil
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
