import SwiftUI
import UniformTypeIdentifiers

struct TaskListView: View {
    enum FocusField: Hashable {
        case task(UUID)
        case scrollView
    }

    enum DragState: Equatable {
        case idle
        case dragging(id: UUID, order: [UUID])
    }

    struct FocusStateData {
        var focusedField: FocusField?
        var selectedTaskID: UUID?
        var pendingFocus: FocusField?
    }

    struct InteractionStateData {
        var dragState: DragState = .idle
    }

    struct TaskStateData {
        var refreshID = UUID()
    }

    @Environment(\.undoManager) var undoManager
    @Environment(\.managedObjectContext) var managedObjectContext

    let store: TaskStore
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TaskItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TaskItem.sortOrder, ascending: true),
        ],
        animation: .default
    )
    var tasks: FetchedResults<TaskItem>
    @FocusState private var focusedFieldBinding: FocusField?
    @State private var fState = FocusStateData()
    @State private var iState = InteractionStateData()
    @State private var tState = TaskStateData()

    var focusedField: FocusField? {
        get { fState.focusedField }
        nonmutating set {
            fState.focusedField = newValue
            focusedFieldBinding = newValue
        }
    }

    var selectedTaskID: UUID? {
        get { fState.selectedTaskID }
        nonmutating set { fState.selectedTaskID = newValue }
    }

    var pendingFocus: FocusField? {
        get { fState.pendingFocus }
        nonmutating set { fState.pendingFocus = newValue }
    }

    var dragState: DragState {
        get { iState.dragState }
        nonmutating set { iState.dragState = newValue }
    }

    var refreshID: UUID {
        get { tState.refreshID }
        nonmutating set { tState.refreshID = newValue }
    }

    var vStackSpacing: CGFloat { 0 }
    var isCompletelyEmpty: Bool { activeTasks.isEmpty && completedTasks.isEmpty }
    var selectedIndex: Int? {
        guard let currentID = selectedTaskID else { return nil }
        return activeTasks.firstIndex(where: { $0.id == currentID })
    }

    var canDeleteSelectionFromList: Bool {
        selectedTaskID != nil && focusedField == .scrollView
    }

    var canMarkSelectionCompleted: Bool {
        guard focusedField == .scrollView else { return false }
        guard let currentID = selectedTaskID else { return false }
        return allTasksInDisplayOrder.contains(where: { $0.id == currentID })
    }

    var markCompletedMenuTitle: String {
        guard let currentID = selectedTaskID,
              let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }),
              task.isCompleted else {
            return "Mark as Complete"
        }
        return "Mark as Incomplete"
    }

    var canMoveSelectionUp: Bool {
        guard focusedField == .scrollView else { return false }
        guard let index = selectedIndex else { return false }
        return index > 0
    }

    var canMoveSelectionDown: Bool {
        guard focusedField == .scrollView else { return false }
        guard let index = selectedIndex else { return false }
        return index < activeTasks.count - 1
    }

    struct MenuState: Equatable {
        let selectedTaskID: UUID?
        let isScrollViewFocused: Bool
        let activeTaskCount: Int
        let completedTaskCount: Int
        let selectedIndex: Int?
    }

    var menuCoordinatorTrigger: MenuState {
        MenuState(
            selectedTaskID: selectedTaskID,
            isScrollViewFocused: focusedField == .scrollView,
            activeTaskCount: activeTasks.count,
            completedTaskCount: completedTasks.count,
            selectedIndex: selectedIndex
        )
    }

    func updateMenuCoordinator() {
        let coord = MenuCoordinator.shared
        coord.newTask = { createNewTask(); focusedField = nil }
        coord.copySelectedTask = {
            guard let taskID = selectedTaskID,
                  let task = tasks.first(where: { $0.id == taskID }) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(task.title, forType: .string)
        }
        coord.cutSelectedTask = {
            guard let taskID = selectedTaskID,
                  let task = tasks.first(where: { $0.id == taskID }) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(task.title, forType: .string)
            deleteTask(task)
        }
        coord.pasteAfterSelectedTask = {
            guard let taskID = selectedTaskID,
                  let string = NSPasteboard.general.string(forType: .string) else { return }
            createTask(title: string, afterTaskID: taskID)
        }
        coord.deleteSelectedTask = { _ = deleteSelectedTask() }
        coord.moveSelectedTaskUp = { moveSelectedTaskUp() }
        coord.moveSelectedTaskDown = { moveSelectedTaskDown() }
        coord.markSelectedTaskCompleted = { markSelectedTaskCompleted() }
        coord.clearCompletedTasks = { clearCompletedTasks() }
        let inNavMode = focusedField == .scrollView
        coord.canCopySelectedTask = selectedTaskID != nil && inNavMode
        coord.canCutSelectedTask = selectedTaskID != nil && inNavMode
        coord.canPasteAfterSelectedTask = selectedTaskID != nil && inNavMode
        coord.canDeleteSelectedTask = canDeleteSelectionFromList
        coord.canMoveSelectedTaskUp = canMoveSelectionUp
        coord.canMoveSelectedTaskDown = canMoveSelectionDown
        coord.canMarkSelectedTaskCompleted = canMarkSelectionCompleted
        coord.markCompletedTitle = markCompletedMenuTitle
        coord.canClearCompletedTasks = !completedTasks.isEmpty
    }

    init(store: TaskStore, syncMonitor: CloudKitSyncMonitor) {
        self.store = store
        self.syncMonitor = syncMonitor
    }

    func didStartDrag() {}

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
                        focusedField: $focusedFieldBinding,
                        onToggle: { toggleCompletion($0) },
                        onTitleChange: { updateTitle($0, $1) },
                        onDelete: { deleteTask($0) },
                        onSelect: { selectTask($0) },
                        onStartEdit: { startEditing($0) },
                        onEndEdit: { endEditing($0, shouldCreateNewTask: $1) },
                        onPaste: { createTask(title: $0, afterTaskID: taskID) }
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
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: TaskReorderDropDelegate(
                                            onTargeted: { updateVisualOrder(insertBefore: task.id) },
                                            onPerform: { commitCurrentDrag() }
                                        )
                                    )

                                // Middle 2/3 - insert based on direction
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(4)
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: TaskReorderDropDelegate(
                                            onTargeted: { updateVisualOrderSmart(relativeTo: task.id) },
                                            onPerform: { commitCurrentDrag() }
                                        )
                                    )

                                // Bottom 1/6 - insert AFTER
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(1)
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: TaskReorderDropDelegate(
                                            onTargeted: { updateVisualOrder(insertAfter: task.id) },
                                            onPerform: { commitCurrentDrag() }
                                        )
                                    )
                            }
                        }
                    }
                }

                // Drop zone at the end
                if !activeTasks.isEmpty && draggedTaskID != nil {
                    Color.clear
                        .frame(height: 44)
                        .onDrop(
                            of: [UTType.text],
                            delegate: TaskReorderDropDelegate(
                                onTargeted: { updateVisualOrder(insertAtEnd: true) },
                                onPerform: { commitCurrentDrag() }
                            )
                        )
                }

                ForEach(completedTasks) { task in
                    let taskID = task.id
                    TaskRowView(
                        task: task,
                        taskID: taskID,
                        isSelected: selectedTaskID == taskID,
                        focusedField: $focusedFieldBinding,
                        onToggle: { toggleCompletion($0) },
                        onTitleChange: { updateTitle($0, $1) },
                        onDelete: { deleteTask($0) },
                        onSelect: { selectTask($0) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .onDrop(
                of: [UTType.text],
                delegate: TaskReorderDropDelegate(
                    onTargeted: {},
                    onPerform: { commitCurrentDrag() }
                )
            )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleBackgroundTap()
        }
        .overlay {
            if isCompletelyEmpty {
                Text("Click to create")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
        }
        .focusable()
        .focused($focusedFieldBinding, equals: .scrollView)
        .focusEffectDisabled()
        .accessibilityIdentifier("task-list-scrollview")
        .keyboardNavigation([
            ShortcutKey(key: .upArrow): navigateUp,
            ShortcutKey(key: .downArrow): navigateDown,
            ShortcutKey(key: .return): focusSelectedTask,
        ])
        .onAppear {
            if focusedFieldBinding == nil {
                focusedFieldBinding = .scrollView
            }
            fState.focusedField = focusedFieldBinding
            updateMenuCoordinator()
        }
        .onChange(of: focusedFieldBinding) { oldValue, newValue in
            fState.focusedField = newValue
            handleFocusChange(from: oldValue, to: newValue)

            if newValue == nil {
                if let pending = pendingFocus {
                    focusedFieldBinding = pending
                    fState.focusedField = pending
                    pendingFocus = nil
                } else {
                    focusedFieldBinding = .scrollView
                    fState.focusedField = .scrollView
                }
            }

            updateMenuCoordinator()
        }
        .onChange(of: menuCoordinatorTrigger) { _, _ in updateMenuCoordinator() }
        .onChange(of: undoManager, initial: true) { _, newValue in
            managedObjectContext.undoManager = newValue
        }
        .toolbar {
            platformToolbar
        }
        .overlay(alignment: .top) {
            syncErrorBanner
        }
        .alert(
            item: Binding(
                get: { syncMonitor.actionableAlert },
                set: { if $0 == nil { syncMonitor.clearActionableAlert() } }
            )
        ) { alert in
            switch alert.action {
            case .openSettings:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Open Settings")) { openSystemSettings() },
                    secondaryButton: .cancel(Text("OK")) {
                        syncMonitor.clearActionableAlert()
                    }
                )

            case .none:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK")) {
                        syncMonitor.clearActionableAlert()
                    }
                )
            }
        }
    }
}

private struct TaskReorderDropDelegate: DropDelegate {
    let onTargeted: () -> Void
    let onPerform: () -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        true
    }

    func dropEntered(info: DropInfo) {
        onTargeted()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        onPerform()
    }
}
