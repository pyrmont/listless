import SwiftUI

struct TaskListView: View {
    enum FocusField: Hashable {
        case task(UUID)
        case scrollView
    }

    @Environment(\.undoManager) private var undoManager
    @Environment(\.managedObjectContext) private var managedObjectContext

    @State private var store: TaskStore
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TaskItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true),
        ],
        animation: .default
    )
    private var tasks: FetchedResults<TaskItem>
    @FocusState var focusedField: FocusField?
    @State var selectedTaskID: UUID?
    @State private var refreshID = UUID()
    @State private var draggedTaskID: UUID?
    @State private var swipingTaskID: UUID?
    @State private var visualOrder: [UUID]?
    @State private var pendingFocus: FocusField?

    init(store: TaskStore = TaskStore()) {
        _store = State(wrappedValue: store)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: vStackSpacing) {
                ForEach(Array(displayActiveTasks.enumerated()), id: \.element.id) { index, task in
                    let taskID = task.id
                    TaskRowView(
                        task: task,
                        taskID: taskID,
                        index: index,
                        totalTasks: displayActiveTasks.count,
                        isSelected: selectedTaskID == taskID,
                        focusedField: $focusedField,
                        onToggle: { toggleCompletion($0) },
                        onTitleChange: { updateTitle($0, $1) },
                        onDelete: { deleteTask($0) },
                        onSelect: { selectTask($0) },
                        onStartEdit: { startEditing($0) },
                        onEndEdit: { endEditing($0, shouldCreateNewTask: $1) }
                    )
                    .taskDragGesture(
                        isActive: !task.isCompleted && swipingTaskID == nil,
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
                                    .dropDestination(
                                        for: String.self, action: { _, _ in false },
                                        isTargeted: { isTargeted in
                                            if isTargeted {
                                                updateVisualOrder(insertBefore: task.id)
                                            }
                                        })

                                // Middle 2/3 - insert based on direction
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(4)
                                    .dropDestination(
                                        for: String.self, action: { _, _ in false },
                                        isTargeted: { isTargeted in
                                            if isTargeted {
                                                updateVisualOrderSmart(relativeTo: task.id)
                                            }
                                        })

                                // Bottom 1/6 - insert AFTER
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(1)
                                    .dropDestination(
                                        for: String.self, action: { _, _ in false },
                                        isTargeted: { isTargeted in
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
                        .dropDestination(
                            for: String.self, action: { _, _ in false },
                            isTargeted: { isTargeted in
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
                        focusedField: $focusedField,
                        onToggle: { toggleCompletion($0) },
                        onTitleChange: { updateTitle($0, $1) },
                        onDelete: { deleteTask($0) },
                        onSelect: { selectTask($0) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            #if os(iOS)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            #endif
            .dropDestination(for: String.self) { items, location in
                handleDrop(items: items)
            }
        }
        #if os(iOS)
        .background {
            Color.outerBackground.ignoresSafeArea()
        }
        #endif
        .contentShape(Rectangle())
        .onTapGesture {
            handleBackgroundTap()
        }
        .focusable()
        .focused($focusedField, equals: .scrollView)
        .focusEffectDisabled()
        .accessibilityIdentifier("task-list-scrollview")
        .keyboardNavigation([
            ShortcutKey(key: .upArrow): navigateUp,
            ShortcutKey(key: .downArrow): navigateDown,
            ShortcutKey(key: .space): toggleSelectedTask,
            ShortcutKey(key: .return): focusSelectedTask,
            ShortcutKey(key: .delete): deleteSelectedTask,
        ])
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
        .onChange(of: undoManager, initial: true) { _, newValue in
            // Connect SwiftUI's undo manager to Core Data context for automatic undo/redo
            managedObjectContext.undoManager = newValue
        }
        .toolbar {
            platformToolbar
        }
    }

    private var vStackSpacing: CGFloat {
        #if os(iOS)
        12
        #else
        0
        #endif
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

    var completedTasks: [TaskItem] {
        Array(tasks.filter { $0.isCompleted })
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var allTasksInDisplayOrder: [TaskItem] {
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

    func createNewTask() {
        // Clear any lingering drag state
        draggedTaskID = nil
        visualOrder = nil

        // Create Core Data task (Core Data assigns the ID)
        let task = store.createTask(title: "")

        // Record intent to focus the new task.
        // pendingFocus is retained for the background-tap flow (focusedField → nil there).
        // focusedField is also set directly for the TappableTextField Return flow (stays non-nil).
        pendingFocus = .task(task.id)
        focusedField = .task(task.id)
        selectedTaskID = task.id
    }

    private func handleBackgroundTap() {
        // Check if a task is focused (not just scrollView)
        let isTaskFocused = if case .task = focusedField { true } else { false }

        if isTaskFocused || selectedTaskID != nil {
            selectedTaskID = nil
            focusedField = nil
        } else {
            createNewTask()
            // Trigger focus resolution by setting to nil
            // onChange(of: focusedField) will then resolve pendingFocus
            focusedField = nil
        }
    }

    private func handleFocusChange(from oldValue: FocusField?, to newValue: FocusField?) {
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

        // Remove this task from undo history since it was never really used
        managedObjectContext.undoManager?.removeAllActions(withTarget: task)

        // Disable undo registration for the delete operation itself
        managedObjectContext.undoManager?.disableUndoRegistration()
        deleteTask(task)
        managedObjectContext.undoManager?.enableUndoRegistration()
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

    private func handleSwipeComplete(_ taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        toggleCompletion(task)
    }

    private func handleSwipeDelete(_ taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        deleteTask(task)
    }

    private func handleSwipeActiveChanged(_ taskID: UUID, _ isActive: Bool) {
        swipingTaskID = isActive ? taskID : nil
    }

    private func selectTask(_ taskID: UUID) {
        selectedTaskID = taskID
    }

    func deleteTask(_ task: TaskItem) {
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

    func clearCompletedTasks() {
        // Delete all completed tasks (in reverse to avoid index issues)
        for task in completedTasks.reversed() {
            store.delete(taskID: task.id)
        }
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
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else {
            return .handled
        }
        toggleCompletion(task)
        return .handled
    }

    private func focusSelectedTask() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }
        guard let currentID = selectedTaskID else { return .handled }
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else {
            return .handled
        }
        guard !task.isCompleted else { return .handled }
        startEditing(currentID)
        return .handled
    }

    private func deleteSelectedTask() -> KeyPress.Result {
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

    private func focusTextField(_ taskID: UUID) {
        focusedField = .task(taskID)
    }

    private func startEditing(_ taskID: UUID) {
        print("🟢 startEditing called for task \(taskID)")
        selectedTaskID = taskID
        focusedField = .task(taskID)
        pendingFocus = nil    // Consume pendingFocus once the field is live
        print("🟢 startEditing set focusedField = .task(\(taskID))")
    }

    private func endEditing(_ taskID: UUID, shouldCreateNewTask: Bool) {
        print(
            "🟢 endEditing() called for task \(taskID), shouldCreateNewTask: \(shouldCreateNewTask)")
        // Save any pending changes
        store.save()

        // Check conditions BEFORE deleting the task
        let wasLastActiveTask = isLastActiveTask(taskID)
        let willBeDeleted = shouldDeleteIfEmpty(taskID: taskID)
        print(
            "🟢 endEditing() wasLastActiveTask: \(wasLastActiveTask), willBeDeleted: \(willBeDeleted)"
        )

        if willBeDeleted {
            print("🟢 endEditing() deleting task - focus will be repaired automatically by onChange")
            selectedTaskID = nil
            deleteIfEmpty(taskID: taskID)
            // No explicit focus management - onChange will repair to .scrollView
        } else if wasLastActiveTask && shouldCreateNewTask {
            print("🟢 endEditing() creating new task")
            createNewTask()
        } else if shouldCreateNewTask {
            print("🟢 endEditing() Return on non-last task — dismiss keyboard, enter navigation mode")
            // TappableTextField returns false from textFieldShouldReturn, so the old field
            // stays first responder. Setting focusedField to .scrollView causes SwiftUI's
            // .focused() to detect the mismatch and call resignFirstResponder(), dismissing
            // the keyboard cleanly.
            focusedField = .scrollView
        } else {
            print("🟢 endEditing() done, selection unchanged")
            // Do NOT restore selectedTaskID = taskID here.
            //
            // On macOS: selectedTaskID is already taskID (set by startEditing when editing
            // began), and AppKit fires controlTextDidEndEditing synchronously before any
            // SwiftUI tap gesture handler runs, so nothing has changed it yet. The line
            // would be a no-op.
            //
            // On iOS: everything flows through onChange(of: focusedField), so onStartEdit
            // on the new row may have already updated selectedTaskID before this fires.
            // Restoring it here would overwrite the new selection.
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
            let order = visualOrder
        else { return }

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
            let order = visualOrder
        else { return }

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
            let order = visualOrder
        else { return }

        // Determine if dragged item is currently above or below target
        guard let draggedIndex = order.firstIndex(of: draggedID),
            let targetIndex = order.firstIndex(of: targetID)
        else { return }

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
            let order = visualOrder
        else { return }

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
            let finalIndex = order.firstIndex(of: droppedUUID)
        else {
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
