import SwiftUI

struct TaskListView: View, TaskListViewProtocol {
    struct FocusStateData {
        var focusedField: FocusField?
        var selectedTaskID: UUID?
        var pendingFocus: FocusField?
    }

    struct InteractionStateData {
        var dragState: DragState = .idle
        var pullToCreate = PullToCreateState()
        var pullUpOffset: CGFloat = 0
        var isDragging: Bool = false
        var clearingTaskIDs: Set<UUID> = []
        var rowFrames: [UUID: CGRect] = [:]
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

    var pullToCreate: PullToCreateState {
        get { iState.pullToCreate }
        nonmutating set { iState.pullToCreate = newValue }
    }

    var pullUpOffset: CGFloat {
        get { iState.pullUpOffset }
        nonmutating set { iState.pullUpOffset = newValue }
    }

    var isDragging: Bool {
        get { iState.isDragging }
        nonmutating set { iState.isDragging = newValue }
    }

    var rowFrames: [UUID: CGRect] {
        get { iState.rowFrames }
        nonmutating set { iState.rowFrames = newValue }
    }

    var refreshID: UUID {
        get { tState.refreshID }
        nonmutating set { tState.refreshID = newValue }
    }

    private var isDraggingStateBinding: Binding<Bool> {
        Binding(
            get: { iState.isDragging },
            set: { iState.isDragging = $0 }
        )
    }

    private var pullToCreateStateBinding: Binding<PullToCreateState> {
        Binding(
            get: { iState.pullToCreate },
            set: { iState.pullToCreate = $0 }
        )
    }

    private var pullUpOffsetStateBinding: Binding<CGFloat> {
        Binding(
            get: { iState.pullUpOffset },
            set: { iState.pullUpOffset = $0 }
        )
    }

    var vStackSpacing: CGFloat { 12 }
    var pullCreateThreshold: CGFloat { 70 }
    var isCompletelyEmpty: Bool { activeTasks.isEmpty && completedTasks.isEmpty }

    init(store: TaskStore, syncMonitor: CloudKitSyncMonitor) {
        self.store = store
        self.syncMonitor = syncMonitor
    }

    func didStartDrag() {
        isDragging = true
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    var body: some View {
        taskScrollView
            .contentShape(Rectangle())
            .onTapGesture {
                handleBackgroundTap()
            }
            .focusable()
            .focused($focusedFieldBinding, equals: .scrollView)
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
                if focusedFieldBinding == nil {
                    focusedFieldBinding = .scrollView
                }
                fState.focusedField = focusedFieldBinding
            }
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

    private var taskScrollView: some View {
        ScrollView {
          ScrollViewReader { scrollProxy in
            VStack(alignment: .leading, spacing: vStackSpacing) {
                navigationHeader
                pullToCreateIndicatorRow
                ForEach(Array(displayActiveTasks.enumerated()), id: \.element.id) { index, task in
                    let taskID = task.id
                    TaskRowView(
                        task: task,
                        taskID: taskID,
                        index: index,
                        totalTasks: displayActiveTasks.count,
                        isSelected: selectedTaskID == taskID,
                        isDragging: isDraggingStateBinding,
                        isLastActiveTask: index == displayActiveTasks.count - 1,
                        focusedField: $focusedFieldBinding,
                        onToggle: { toggleCompletion($0) },
                        onTitleChange: { updateTitle($0, $1) },
                        onDelete: { deleteTask($0) },
                        onSelect: { selectTask($0) },
                        onStartEdit: { startEditing($0) },
                        onEndEdit: { endEditing($0, shouldCreateNewTask: $1) }
                    )
                    .scaleEffect(draggedTaskID == taskID ? 1.05 : 1.0)
                    .shadow(
                        color: draggedTaskID == taskID ? .black.opacity(0.3) : .clear,
                        radius: 12, y: 4
                    )
                    .zIndex(draggedTaskID == taskID ? 1 : 0)
                    .taskDragGesture(
                        isActive: !task.isCompleted,
                        taskID: taskID,
                        onDragStart: { startDrag(taskID: taskID) },
                        onDragChanged: { point in handleIOSDragChanged(taskID: taskID, point: point) },
                        onDragEnded: { commitIOSDrag() }
                    )
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        rowFrames[taskID] = frame
                    }
                    .id(taskID)
                }

                ForEach(completedTasks) { task in
                    let taskID = task.id
                    let isBeingCleared = iState.clearingTaskIDs.contains(taskID)
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
                    .opacity(isBeingCleared ? 0 : 1)
                    .offset(y: isBeingCleared ? 40 : 0)
                    .id(taskID)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
            .offset(y: -pullToCreate.pullOffset)
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

                if case .task(let id) = (newValue ?? fState.focusedField),
                    draggedTaskID == nil
                {
                    withAnimation {
                        scrollProxy.scrollTo(id)
                    }
                }
            }
            .onChange(of: fState.selectedTaskID) { _, newID in
                if let newID, draggedTaskID == nil {
                    withAnimation {
                        scrollProxy.scrollTo(newID)
                    }
                }
            }
          }
        }
        .scrollDisabled(draggedTaskID != nil)
        .scrollBounceBehavior(.always)
        .contentMargins(.bottom, 20)
        .background {
            Color.outerBackground.ignoresSafeArea()
        }
        .overlay {
            if isCompletelyEmpty {
                Text("Pull down to create")
                    .font(TaskRowMetrics.hintSUI)
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            pullToClearIndicatorRow
        }
            .pullCreationGesture(
                pullToCreate: pullToCreateStateBinding,
                pullUpOffset: pullUpOffsetStateBinding,
                activeTaskIDs: activeTasks.map(\.id),
                hasCompletedTasks: !completedTasks.isEmpty,
            pullCreateThreshold: pullCreateThreshold,
            pullClearThreshold: pullClearThreshold,
            onCreateTaskAtTop: { createNewTaskAtTop() },
            onClearCompleted: {
                let ids = Set(completedTasks.map(\.id))
                withAnimation(.easeIn(duration: 0.35)) {
                    iState.clearingTaskIDs = ids
                } completion: {
                    iState.clearingTaskIDs = []
                    clearCompletedTasks()
                }
            }
        )
    }
}
