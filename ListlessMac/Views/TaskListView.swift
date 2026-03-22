import SwiftUI
import UniformTypeIdentifiers

struct TaskListView: View, TaskListViewProtocol {
    struct InteractionStateData {
        var dragState: DragState = .idle
        var liftedTaskID: UUID?
        var draftPlacement: DraftTaskPlacement?
        var draftTitle: String = ""
    }

    @AppStorage("colorTheme") private var colorThemeRaw = 0
    private var colorTheme: ColorTheme { ColorTheme(rawValue: colorThemeRaw) ?? .pilbara }

    @Environment(\.undoManager) var undoManager
    @Environment(\.managedObjectContext) var managedObjectContext

    let store: TaskStore
    let windowCoordinator: WindowCoordinator
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    @FetchRequest(
        sortDescriptors: [],
        animation: .default
    )
    var tasks: FetchedResults<TaskItem>
    @FocusState private var focusedFieldBinding: FocusField?
    @State var fState = FocusStateData()
    @State private var iState = InteractionStateData()

    var focusedField: FocusField? {
        get { fState.focusedField }
        nonmutating set {
            fState.focusedField = newValue
            focusedFieldBinding = newValue
        }
    }

    var dragState: DragState {
        get { iState.dragState }
        nonmutating set { iState.dragState = newValue }
    }

    var draftPlacement: DraftTaskPlacement? {
        get { iState.draftPlacement }
        nonmutating set { iState.draftPlacement = newValue }
    }

    var draftTitle: String {
        get { iState.draftTitle }
        nonmutating set { iState.draftTitle = newValue }
    }

    var vStackSpacing: CGFloat { 0 }
    var isCompletelyEmpty: Bool { activeTasks.isEmpty && completedTasks.isEmpty }
    var selectedIndex: Int? {
        guard let currentID = fState.selectedTaskID else { return nil }
        return activeTasks.firstIndex(where: { $0.id == currentID })
    }

    var canDeleteSelectionFromList: Bool {
        !fState.selectedTaskIDs.isEmpty && focusedField == .scrollView
    }

    var canMarkSelectionCompleted: Bool {
        guard focusedField == .scrollView else { return false }
        let selected = allTasksInDisplayOrder.filter { fState.isTaskSelected($0.id) }
        guard !selected.isEmpty else { return false }
        let hasActive = selected.contains { !$0.isCompleted }
        let hasCompleted = selected.contains { $0.isCompleted }
        return !(hasActive && hasCompleted)
    }

    var markCompletedMenuTitle: String {
        if fState.hasMultipleSelection {
            let hasCompleted = completedTasks.contains(where: { fState.isTaskSelected($0.id) })
            return hasCompleted ? "Mark as Incomplete" : "Mark as Complete"
        }
        return completedTasks.contains(where: { $0.id == fState.selectedTaskID })
            ? "Mark as Incomplete" : "Mark as Complete"
    }

    var canMoveSelectionUp: Bool {
        guard focusedField == .scrollView else { return false }
        guard !fState.hasMultipleSelection else { return false }
        guard let index = selectedIndex else { return false }
        return index > 0
    }

    var canMoveSelectionDown: Bool {
        guard focusedField == .scrollView else { return false }
        guard !fState.hasMultipleSelection else { return false }
        guard let index = selectedIndex else { return false }
        return index < activeTasks.count - 1
    }

    struct MenuState: Equatable {
        let selectedTaskIDs: Set<UUID>
        let isScrollViewFocused: Bool
        let activeTaskCount: Int
        let completedTaskCount: Int
        let selectedIndex: Int?
    }

    var windowCoordinatorTrigger: MenuState {
        MenuState(
            selectedTaskIDs: fState.selectedTaskIDs,
            isScrollViewFocused: focusedField == .scrollView,
            activeTaskCount: activeTasks.count,
            completedTaskCount: completedTasks.count,
            selectedIndex: selectedIndex
        )
    }

    func updateWindowCoordinator() {
        let coord = windowCoordinator
        coord.newTask = { createNewTask() }
        coord.copySelectedTask = {
            guard let taskID = fState.selectedTaskID,
                  let task = tasks.first(where: { $0.id == taskID }) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(task.title, forType: .string)
        }
        coord.cutSelectedTask = {
            guard let taskID = fState.selectedTaskID,
                  let task = tasks.first(where: { $0.id == taskID }) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(task.title, forType: .string)
            deleteTask(task)
        }
        coord.pasteAfterSelectedTask = {
            guard let taskID = fState.selectedTaskID,
                  let string = NSPasteboard.general.string(forType: .string) else { return }
            createTask(title: string, afterTaskID: taskID)
        }
        coord.deleteSelectedTask = { _ = deleteSelectedTask() }
        coord.moveSelectedTaskUp = { moveSelectedTaskUp() }
        coord.moveSelectedTaskDown = { moveSelectedTaskDown() }
        coord.markSelectedTaskCompleted = { markSelectedTaskCompleted() }
        coord.selectAllTasks = {
            fState.selectAll(displayOrder: allTasksInDisplayOrder.map(\.id))
        }
        coord.clearCompletedTasks = { clearCompletedTasks() }
        let inNavMode = focusedField == .scrollView
        let singleSelect = !fState.selectedTaskIDs.isEmpty && !fState.hasMultipleSelection
        coord.canSelectAllTasks = inNavMode && !allTasksInDisplayOrder.isEmpty
        coord.canCopySelectedTask = singleSelect && inNavMode
        coord.canCutSelectedTask = singleSelect && inNavMode
        coord.canPasteAfterSelectedTask = selectedIndex != nil && singleSelect && inNavMode
        coord.canDeleteSelectedTask = canDeleteSelectionFromList
        coord.canMoveSelectedTaskUp = canMoveSelectionUp
        coord.canMoveSelectedTaskDown = canMoveSelectionDown
        coord.canMarkSelectedTaskCompleted = canMarkSelectionCompleted
        coord.markCompletedTitle = markCompletedMenuTitle
        coord.canClearCompletedTasks = !completedTasks.isEmpty
    }

    init(store: TaskStore, syncMonitor: CloudKitSyncMonitor, windowCoordinator: WindowCoordinator) {
        self.store = store
        self.syncMonitor = syncMonitor
        self.windowCoordinator = windowCoordinator
    }

    func isRowLifted(_ taskID: UUID) -> Bool {
        iState.liftedTaskID == taskID || draggedTaskID == taskID
    }

    func clearDraftTaskUI(at placement: DraftTaskPlacement, hasTitle _: Bool) {
        if draftPlacement == placement {
            draftPlacement = nil
        }
        draftTitle = ""
        if fState.selectedTaskID == draftID(for: placement) {
            fState.selectedTaskID = nil
        }
        // Resign AppKit first responder explicitly — SwiftUI's @FocusState
        // and AppKit's responder chain are parallel systems, so setting
        // focusedField alone may not dismiss the NSTextField.
        NSApp.keyWindow?.makeFirstResponder(nil)
        focusedField = nil
    }

    func didStartDrag() {}

    var body: some View {
        ScrollView {
          ScrollViewReader { scrollProxy in
            VStack(alignment: .leading, spacing: vStackSpacing) {
                ForEach(Array(displayActiveTasks.enumerated()), id: \.element.id) { index, task in
                    let taskID = task.id
                    TaskRowView(
                        task: task,
                        taskID: taskID,
                        index: index,
                        totalTasks: displayActiveTasks.count,
                        isSelected: fState.isTaskSelected(taskID),
                        focusedField: $focusedFieldBinding,
                        onToggle: { toggleCompletion($0) },
                        onTitleChange: { updateTitle($0, $1) },
                        onDelete: { deleteTask($0) },
                        onSelect: {
                            let modifiers = NSApp.currentEvent?.modifierFlags ?? []
                            selectTask(
                                $0,
                                extendSelection: modifiers.contains(.shift),
                                toggleSelection: modifiers.contains(.command)
                            )
                        },
                        onStartEdit: { startEditing($0) },
                        onEndEdit: { endEditing($0, shouldCreateNewTask: $1) },
                        onPaste: { createTask(title: $0, afterTaskID: taskID) }
                    )
                    .taskDragGesture(
                        isActive: !task.isCompleted,
                        taskID: task.id,
                        onDragStart: {
                            iState.liftedTaskID = nil
                            startDrag(taskID: task.id)
                        },
                        onLift: { iState.liftedTaskID = task.id },
                        onLiftEnd: {
                            if iState.liftedTaskID == task.id { iState.liftedTaskID = nil }
                            if draggedTaskID == task.id { clearDragState() }
                        }
                    )
                    .scaleEffect(isRowLifted(taskID) ? 1.03 : 1.0)
                    .shadow(
                        color: isRowLifted(taskID) ? .black.opacity(0.2) : .clear,
                        radius: 8, y: 3
                    )
                    .zIndex(isRowLifted(taskID) ? 1 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isRowLifted(taskID))
                    .overlay {
                        if draggedTaskID != nil && draggedTaskID != taskID {
                            VStack(spacing: 0) {
                                // Top 1/6 - insert BEFORE
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(1)
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: TaskReorderDropDelegate(
                                            onTargeted: { updateVisualOrder(insertBefore: taskID) },
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
                                            onTargeted: { updateVisualOrderSmart(relativeTo: taskID) },
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
                                            onTargeted: { updateVisualOrder(insertAfter: taskID) },
                                            onPerform: { commitCurrentDrag() }
                                        )
                                    )
                            }
                        }
                    }
                }

                if draftPlacement == .append {
                    let total = max(1, displayActiveTasks.count + 1)
                    let index = displayActiveTasks.count
                    let accentColor = cachedTaskColor(
                        forIndex: index, total: total, theme: colorTheme
                    )
                    let isSelected = fState.isTaskSelected(draftAppendRowID)
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "circle")
                            .foregroundStyle(.primary)
                            .font(.system(size: 17))
                            .fontWeight(.thin)
                            .alignmentGuide(.firstTextBaseline) { d in
                                d[VerticalAlignment.center] + 5
                            }

                        ClickableTextField(
                            text: Binding(
                                get: { iState.draftTitle },
                                set: { iState.draftTitle = $0 }
                            ),
                            isCompleted: false,
                            onEditingChanged: { editing, shouldCreateNewTask in
                                if editing {
                                    beginDraftTaskEditing(.append)
                                } else {
                                    commitDraftTask(
                                        shouldCreateNewTask: shouldCreateNewTask
                                    )
                                }
                            },
                            taskID: draftAppendRowID
                        )
                        .focused(
                            $focusedFieldBinding,
                            equals: .task(draftAppendRowID)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 4)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .background(
                        isSelected
                            ? RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            : nil
                    )
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(accentColor)
                            .frame(width: 4)
                            .padding(.vertical, 1)
                    }
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(accentColor.opacity(0.40), lineWidth: 2)
                        }
                    }
                    .accessibilityIdentifier("draft-row-append")
                    .id(draftAppendRowID)
                }

                ForEach(completedTasks) { task in
                    let taskID = task.id
                    TaskRowView(
                        task: task,
                        taskID: taskID,
                        isSelected: fState.isTaskSelected(taskID),
                        focusedField: $focusedFieldBinding,
                        onToggle: { toggleCompletion($0) },
                        onTitleChange: { updateTitle($0, $1) },
                        onDelete: { deleteTask($0) },
                        onSelect: {
                            selectTask(
                                $0,
                                extendSelection: NSEvent.modifierFlags.contains(.shift)
                            )
                        }
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
            .onChange(of: focusedFieldBinding) { _, newValue in
                if case .task(let id) = (newValue ?? fState.focusedField),
                    draggedTaskID == nil,
                    id != draftPrependRowID
                {
                    withAnimation {
                        scrollProxy.scrollTo(id)
                    }
                }
            }
            .onChange(of: fState.selectedTaskID) { _, newID in
                if let newID, draggedTaskID == nil {
                    guard newID != draftPrependRowID else { return }
                    withAnimation {
                        scrollProxy.scrollTo(newID)
                    }
                }
            }
          }
        }
        .onDrop(
            of: [UTType.text],
            delegate: TaskReorderDropDelegate(
                onTargeted: {},
                onPerform: { commitCurrentDrag() }
            )
        )
        .background {
            BackgroundClickMonitor {
                handleBackgroundTap()
            }
        }
        .background(Color.outerBackground)
        .overlay {
            if isCompletelyEmpty && draftPlacement == nil {
                Text("Click to create")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("empty-state-label")
            }
        }
        .focusable()
        .focused($focusedFieldBinding, equals: .scrollView)
        .focusEffectDisabled()
        .accessibilityIdentifier("task-list-scrollview")
        .keyboardNavigation([
            ShortcutKey(key: .upArrow): navigateUp,
            ShortcutKey(key: .downArrow): navigateDown,
            ShortcutKey(key: .upArrow, modifiers: .shift): navigateUpExtend,
            ShortcutKey(key: .downArrow, modifiers: .shift): navigateDownExtend,
            ShortcutKey(key: .return): focusSelectedTask,
        ])
        .onAppear {
            if focusedFieldBinding == nil {
                focusedFieldBinding = .scrollView
            }
            fState.focusedField = focusedFieldBinding
            updateWindowCoordinator()
        }
        .onChange(of: focusedFieldBinding) { oldValue, newValue in
            // Clear the per-window focus gate once we've landed on
            // a non-nil value (reconciliation is done). Keep it set
            // while nil so the redirect below doesn't open a window
            // for AppKit's key-view loop.
            if newValue != nil {
                windowCoordinator.allowedFocusTarget = nil
            }
            fState.focusedField = newValue
            handleFocusChange(from: oldValue, to: newValue)

            if let pending = fState.pendingFocus, newValue != pending {
                // Focus landed somewhere other than the intended
                // target (or went nil). Set the allowed target so
                // the text field can claim focus in
                // viewDidMoveToWindow if it's not yet in the
                // hierarchy, and redirect immediately in case it is.
                windowCoordinator.allowedFocusTarget = pending
                fState.pendingFocus = nil
                focusedField = pending
            } else if newValue == nil {
                focusedField = .scrollView
            }

            updateWindowCoordinator()
        }
        .onChange(of: windowCoordinatorTrigger) { _, _ in updateWindowCoordinator() }
        .onChange(of: undoManager, initial: true) { _, newValue in
            managedObjectContext.undoManager = newValue
        }
        .toolbar {
            platformToolbar
        }
        .safeAreaInset(edge: .bottom) {
            syncErrorBanner
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
