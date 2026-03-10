import SwiftUI
import UIKit

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
        var isShowingSyncDiagnostics = false
        var isShowingSettings = false
        var clearingTaskIDs: Set<UUID> = []
        var rowFrames: [UUID: CGRect] = [:]
        var undoToast: UndoToastData? = nil
        var phantomRowVisible: Bool = false
        var phantomTitle: String = ""
    }

    static let phantomRowID = UUID()

    struct TaskStateData {
        var refreshID = UUID()
    }

    @AppStorage("headingText") var headingText = "Items"
    @Environment(\.undoManager) var undoManager
    @Environment(\.managedObjectContext) var managedObjectContext

    let store: TaskStore
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    @FetchRequest(
        sortDescriptors: [],
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

    var undoToast: UndoToastData? {
        get { iState.undoToast }
        nonmutating set { iState.undoToast = newValue }
    }

    var phantomRowVisible: Bool {
        get { iState.phantomRowVisible }
        nonmutating set { iState.phantomRowVisible = newValue }
    }

    var phantomTitle: String {
        get { iState.phantomTitle }
        nonmutating set { iState.phantomTitle = newValue }
    }

    var phantomTitleBinding: Binding<String> {
        Binding(
            get: { iState.phantomTitle },
            set: { iState.phantomTitle = $0 }
        )
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

    private var isShowingSyncDiagnosticsStateBinding: Binding<Bool> {
        Binding(
            get: { iState.isShowingSyncDiagnostics },
            set: { iState.isShowingSyncDiagnostics = $0 }
        )
    }

    private var selectedIndex: Int? {
        guard let currentID = selectedTaskID else { return nil }
        return activeTasks.firstIndex(where: { $0.id == currentID })
    }

    private var canMoveSelectionUp: Bool {
        guard focusedField == .scrollView else { return false }
        guard let index = selectedIndex else { return false }
        return index > 0
    }

    private var canMoveSelectionDown: Bool {
        guard focusedField == .scrollView else { return false }
        guard let index = selectedIndex else { return false }
        return index < activeTasks.count - 1
    }

    private struct MenuState: Equatable {
        let selectedTaskID: UUID?
        let isScrollViewFocused: Bool
        let activeTaskCount: Int
        let completedTaskCount: Int
        let selectedIndex: Int?
    }

    private var menuCoordinatorTrigger: MenuState {
        MenuState(
            selectedTaskID: selectedTaskID,
            isScrollViewFocused: focusedField == .scrollView,
            activeTaskCount: activeTasks.count,
            completedTaskCount: completedTasks.count,
            selectedIndex: selectedIndex
        )
    }

    func updateMenuCoordinator() {
        let coord = IOSMenuCoordinator.shared
        coord.newTask = { createNewTask() }
        coord.deleteTask = { _ = deleteSelectedTaskWithUndo() }
        coord.moveUp = { moveSelectedTaskUp() }
        coord.moveDown = { moveSelectedTaskDown() }
        coord.markCompleted = { markSelectedTaskCompleted() }
        let inNavMode = focusedField == .scrollView
        coord.canDelete = selectedTaskID != nil && inNavMode
        coord.canMoveUp = canMoveSelectionUp
        coord.canMoveDown = canMoveSelectionDown
        coord.canMarkCompleted = selectedTaskID != nil && inNavMode
        coord.markCompletedTitle = completedTasks.contains(where: { $0.id == selectedTaskID })
            ? "Mark as Incomplete" : "Mark as Complete"
    }

    var vStackSpacing: CGFloat { 12 }
    var pullCreateThreshold: CGFloat { 70 }
    @AppStorage("flickThreshold") var flickThreshold: Double = 800
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

    func showSyncDiagnostics() {
        iState.isShowingSyncDiagnostics = true
    }

    func showSettings() {
        iState.isShowingSettings = true
    }

    private func dragScaleEffect(for taskID: UUID) -> CGFloat {
        let liftPoints: CGFloat = 20
        guard let width = rowFrames[taskID]?.width, width > 0 else { return 1.05 }
        return (width + liftPoints) / width
    }

    /// Combined indicator and phantom entry row sharing the same VStack slot.
    /// The phantom's UITextView is created while the indicator is visible
    /// (during the pull), so it's ready when the user releases.
    @ViewBuilder var pullToCreateIndicatorRow: some View {
        let showIndicator = pullToCreate.shouldShowIndicator
        let showPhantom = iState.phantomRowVisible
        if showIndicator || showPhantom {
            ZStack(alignment: .topLeading) {
                PullToCreateIndicator(
                    pullOffset: pullToCreate.indicatorDisplayOffset(
                        threshold: pullCreateThreshold
                    ),
                    threshold: pullCreateThreshold
                )
                .opacity(showPhantom ? 0 : 1)

                phantomEntryRowContent
                    .frame(height: showPhantom ? nil : 0)
                    .opacity(showPhantom ? 1 : 0)
                    // Instant swap — no animation on height or opacity.
                    .animation(nil, value: showPhantom)
            }
        }
    }

    /// The phantom row content styled to match a task row. Controlled by the
    /// ZStack in ``pullToCreateIndicatorRow`` rather than its own visibility.
    @ViewBuilder private var phantomEntryRowContent: some View {
        let accentColor = taskColor(
            forIndex: 0, total: max(1, displayActiveTasks.count + 1)
        )
        HStack(alignment: .center, spacing: TaskRowMetrics.contentSpacing) {
            Image(systemName: "circle")
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.secondary)
                .font(.system(size: 17))

            TappableTextField(
                text: phantomTitleBinding,
                isCompleted: false,
                isDragging: false,
                onEditingChanged: { editing, _ in
                    DispatchQueue.main.async {
                        if !editing {
                            commitPhantomRow()
                        }
                    }
                },
                returnKeyType: .done
            )
            .focused($focusedFieldBinding, equals: .task(Self.phantomRowID))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, TaskRowMetrics.contentVerticalPadding)
        .padding(.trailing, TaskRowMetrics.contentHorizontalPadding)
        .padding(.leading, TaskRowMetrics.activeLeadingPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            Color.taskCard.overlay(accentColor.opacity(0.15))
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: TaskRowMetrics.trailingCornerRadius,
                topTrailingRadius: TaskRowMetrics.trailingCornerRadius
            )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accentColor)
                .frame(width: TaskRowMetrics.accentBarWidth)
        }
    }

    var body: some View {
        taskScrollView
            .contentShape(Rectangle())
            .onTapGesture {
                handleBackgroundTap()
            }
            .accessibilityIdentifier("task-list-scrollview")
            .background {
                let isEditing = if case .task = focusedFieldBinding { true } else { false }
                let isShowingSheet = iState.isShowingSettings || iState.isShowingSyncDiagnostics
                KeyCommandBridge(
                    isActive: !isEditing && !isShowingSheet,
                    onUp: { _ = navigateUp() },
                    onDown: { _ = navigateDown() },
                    onSpace: { _ = toggleSelectedTask() },
                    onReturn: { _ = focusSelectedTask() },
                    onDelete: { _ = deleteSelectedTaskWithUndo() }
                )
            }
            .onAppear {
                fState.focusedField = .scrollView
                updateMenuCoordinator()
            }
            .onChange(of: menuCoordinatorTrigger) { _, _ in updateMenuCoordinator() }
            .onChange(of: undoManager, initial: true) { _, newValue in
                managedObjectContext.undoManager = newValue
            }
            .toolbar {
                platformToolbar
            }
            .safeAreaInset(edge: .bottom) {
                syncErrorBanner
            }
            .overlay(alignment: .bottom) {
                if let toast = iState.undoToast {
                    UndoToastView(
                        data: toast,
                        onUndo: { performUndo() },
                        onDismiss: { dismissUndoToast() }
                    )
                }
            }
            .task(id: iState.undoToast?.id) {
                guard iState.undoToast != nil else { return }
                try? await Task.sleep(for: .seconds(7))
                guard !Task.isCancelled else { return }
                dismissUndoToast()
            }
            .sheet(isPresented: isShowingSyncDiagnosticsStateBinding) {
                NavigationStack {
                    SyncDiagnosticsView(syncMonitor: syncMonitor)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { iState.isShowingSyncDiagnostics = false }
                            }
                        }
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { iState.isShowingSettings },
                    set: { iState.isShowingSettings = $0 }
                )
            ) {
                SettingsView(syncMonitor: syncMonitor)
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
                        onDelete: { deleteTaskWithUndo($0) },
                        onSelect: { selectTask($0) },
                        onStartEdit: { startEditing($0) },
                        onEndEdit: {
                            selectedTaskID = nil
                            endEditing($0, shouldCreateNewTask: $1)
                        }
                    )
                    .scaleEffect(draggedTaskID == taskID ? dragScaleEffect(for: taskID) : 1.0)
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
                        onDelete: { deleteTaskWithUndo($0) },
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

                if newValue == nil,
                    !iState.isShowingSettings,
                    !iState.isShowingSyncDiagnostics
                {
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
            .pullGestures(
                pullToCreate: pullToCreateStateBinding,
                pullUpOffset: pullUpOffsetStateBinding,
                isDragging: isDraggingStateBinding,
                activeTaskIDs: activeTasks.map(\.id),
                hasCompletedTasks: !completedTasks.isEmpty,
            pullCreateThreshold: pullCreateThreshold,
            flickThreshold: flickThreshold,
            pullClearThreshold: pullClearThreshold,
            onCreateTaskAtTop: { revealPhantomRow() },
            onClearCompleted: {
                let ids = Set(completedTasks.map(\.id))
                withAnimation(.easeIn(duration: 0.35)) {
                    iState.clearingTaskIDs = ids
                } completion: {
                    iState.clearingTaskIDs = []
                    clearCompletedTasksWithUndo()
                }
            }
        )
    }
}
