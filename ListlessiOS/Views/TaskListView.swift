import SwiftUI
import UIKit

struct TaskListView: View, TaskListViewProtocol {
    class LayoutStorage {
        var rowFrames: [UUID: CGRect] = [:]
        var contentBottomY: CGFloat = 0
    }

    struct InteractionStateData {
        var dragState: DragState = .idle
        var draftCount: Int = 0
        var isShowingSyncDiagnostics = false
        var isShowingSettings = false
        var clearingTaskIDs: Set<UUID> = []
        var undoToast: UndoToastData? = nil
        var isSwiping: Bool = false
        var draftPlacement: DraftTaskPlacement?
        var draftTitle: String = ""
        var fetchWorkaround: Int = 0
    }

    struct PullStateData {
        var pullToCreate = PullToCreateState()
        var pullUpOffset: CGFloat = 0
        var frozenOffset: CGFloat = 0

        var scrollUpAmount: CGFloat = 0
        var headerHeight: CGFloat = 60
    }

    @AppStorage("headingText") var headingText = "Items"
    @AppStorage("colorTheme") private var colorThemeRaw = 0
    private var colorTheme: ColorTheme { ColorTheme(rawValue: colorThemeRaw) ?? .pilbara }
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
    @State var fState = FocusStateData()
    @State var iState = InteractionStateData()
    @State var pState = PullStateData()
    @State var isDragging = false
    @State var layoutStorage = LayoutStorage()

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
        nonmutating set {
            if newValue != nil, iState.draftPlacement == nil {
                iState.draftCount += 1
            }
            iState.draftPlacement = newValue
        }
    }

    var draftTitle: String {
        get { iState.draftTitle }
        nonmutating set { iState.draftTitle = newValue }
    }

    private var isPrependDraftVisible: Bool {
        draftPlacement == .prepend
    }

    private var isAppendDraftVisible: Bool {
        draftPlacement == .append
    }

    var draftTitleBinding: Binding<String> {
        Binding(
            get: { iState.draftTitle },
            set: { iState.draftTitle = $0 }
        )
    }

    private var isDraggingStateBinding: Binding<Bool> {
        $isDragging
    }

    private var pullToCreateStateBinding: Binding<PullToCreateState> {
        Binding(
            get: { pState.pullToCreate },
            set: { pState.pullToCreate = $0 }
        )
    }

    private var pullUpOffsetStateBinding: Binding<CGFloat> {
        Binding(
            get: { pState.pullUpOffset },
            set: { pState.pullUpOffset = $0 }
        )
    }

    private var isShowingSyncDiagnosticsStateBinding: Binding<Bool> {
        Binding(
            get: { iState.isShowingSyncDiagnostics },
            set: { iState.isShowingSyncDiagnostics = $0 }
        )
    }

    private var selectedIndex: Int? {
        guard let currentID = fState.selectedTaskID else { return nil }
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
            selectedTaskID: fState.selectedTaskID,
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
        coord.canDelete = fState.selectedTaskID != nil && inNavMode
        coord.canMoveUp = canMoveSelectionUp
        coord.canMoveDown = canMoveSelectionDown
        coord.canMarkCompleted = fState.selectedTaskID != nil && inNavMode
        coord.markCompletedTitle = completedTasks.contains(where: { $0.id == fState.selectedTaskID })
            ? "Mark as Incomplete" : "Mark as Complete"
    }

    var vStackSpacing: CGFloat { 0 }
    var rowGap: CGFloat { 12 }
    var pullCreateThreshold: CGFloat { 70 }
    var flickThreshold: CGFloat { 500 }
    var isCompletelyEmpty: Bool { activeTasks.isEmpty && completedTasks.isEmpty }

    init(store: TaskStore, syncMonitor: CloudKitSyncMonitor) {
        self.store = store
        self.syncMonitor = syncMonitor
    }

    func clearDraftTaskUI(at placement: DraftTaskPlacement, hasTitle: Bool) {
        let clear: () -> Void = {
            if draftPlacement == placement {
                draftPlacement = nil
            }
            draftTitle = ""
            if fState.selectedTaskID == draftID(for: placement) {
                fState.selectedTaskID = nil
            }

            guard placement == .prepend else { return }

            pState.frozenOffset = 0
            var state = pState.pullToCreate
            state.isInsertionPending = false
            state.indicatorOffset = 0
            pState.pullToCreate = state
        }

        if placement == .prepend, !hasTitle {
            withAnimation(.spring(response: 0.24, dampingFraction: 1.0)) {
                clear()
            }
        } else if placement == .prepend {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                clear()
            }
        } else {
            clear()
        }

        if placement == .prepend || !hasTitle {
            focusedField = nil
        }
    }

    func didStartDrag() {
        isDragging = true
        let generator = UIImpactFeedbackGenerator(style: .light)
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
        guard let width = layoutStorage.rowFrames[taskID]?.width, width > 0 else { return 1.05 }
        return (width + liftPoints) / width
    }

    /// Combined indicator and phantom entry row sharing the same VStack slot.
    /// The phantom's UITextView is created while the indicator is visible
    /// (during the pull), so it's ready when the user releases.
    @ViewBuilder var pullToCreateIndicatorRow: some View {
        let pullOffset = pState.pullToCreate.pullOffset
        let indicatorHeight = PullToCreateIndicator.indicatorHeight
        PullToCreateIndicator(
            pullOffset: max(
                0,
                pState.pullToCreate.indicatorDisplayOffset(
                    threshold: pullCreateThreshold
                )
            ),
            threshold: pullCreateThreshold
        )
        .frame(
            height: isPrependDraftVisible
                ? 0
                : min(pullOffset, indicatorHeight + rowGap),
            alignment: .top
        )
        .opacity(isPrependDraftVisible || pullOffset <= 0 ? 0 : 1)
    }

    /// The draft row content styled to match a task row. Controlled by the
    /// ZStack in ``pullToCreateIndicatorRow`` rather than its own visibility.
    @ViewBuilder private var draftPrependRow: some View {
        DraftRowView(
            accentColor: taskColor(
                forIndex: 0, total: max(1, displayActiveTasks.count + 1), theme: colorTheme
            ),
            isSelected: fState.selectedTaskID == draftPrependRowID,
            draftID: draftPrependRowID,
            title: draftTitleBinding,
            onEditingChanged: { editing, _ in
                DispatchQueue.main.async {
                    if editing {
                        beginDraftTaskEditing(.prepend)
                    } else {
                        commitDraftTask()
                    }
                }
            },
            returnKeyType: .done,
            accessibilityIdentifier: "draft-row-prepend",
            focusedField: $focusedFieldBinding
        )
    }

    @ViewBuilder private var draftAppendRow: some View {
        if isAppendDraftVisible {
            DraftRowView(
                accentColor: taskColor(
                    forIndex: displayActiveTasks.count,
                    total: max(1, displayActiveTasks.count + 1),
                    theme: colorTheme
                ),
                isSelected: fState.selectedTaskID == draftAppendRowID,
                draftID: draftAppendRowID,
                title: draftTitleBinding,
                onEditingChanged: { editing, shouldCreateNewTask in
                    DispatchQueue.main.async {
                        if editing {
                            beginDraftTaskEditing(.append)
                        } else {
                            commitDraftTask(
                                shouldCreateNewTask: shouldCreateNewTask
                            )
                        }
                    }
                },
                returnKeyType: draftTitle.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty ? .done : .next,
                accessibilityIdentifier: "draft-row-append",
                focusedField: $focusedFieldBinding
            )
            .padding(.bottom, rowGap)
            .id(draftAppendRowID)
        }
    }

    @ViewBuilder private var taskRows: some View {
        let _ = iState.fetchWorkaround
        let draftOffset = isPrependDraftVisible ? 1 : 0
        let draftTotal = draftPlacement != nil ? 1 : 0
        ForEach(Array(displayActiveTasks.enumerated()), id: \.element.id) { index, task in
            let taskID = task.id
            TaskRowView(
                task: task,
                taskID: taskID,
                index: index + draftOffset,
                totalTasks: displayActiveTasks.count + draftTotal,
                isSelected: fState.selectedTaskID == taskID,
                isDragging: isDraggingStateBinding,
                isSwiping: $iState.isSwiping,
                isLastActiveTask: index == displayActiveTasks.count - 1,
                focusedField: $focusedFieldBinding,
                onToggle: { toggleCompletion($0); withAnimation { iState.fetchWorkaround &+= 1 } },
                onTitleChange: { updateTitle($0, $1) },
                onDelete: { deleteTaskWithUndo($0) },
                onSelect: { selectTask($0) },
                onStartEdit: { startEditing($0) },
                onEndEdit: {
                    if fState.selectedTaskID == $0 {
                        fState.selectedTaskID = nil
                    }
                    endEditing($0, shouldCreateNewTask: $1)
                }
            )
            .scaleEffect(draggedTaskID == taskID ? dragScaleEffect(for: taskID) : 1.0)
            .shadow(
                color: draggedTaskID == taskID ? .black.opacity(0.3) : .clear,
                radius: 12, y: 4
            )
            .zIndex(draggedTaskID == taskID ? 2 : 1)
            .taskDragGesture(
                isActive: !task.isCompleted && focusedFieldBinding != .task(taskID),
                taskID: taskID,
                onDragStart: { startDrag(taskID: taskID) },
                onDragChanged: { point in handleIOSDragChanged(taskID: taskID, point: point) },
                onDragEnded: { commitIOSDrag() }
            )
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                layoutStorage.rowFrames[taskID] = frame
            }
            .padding(.bottom, rowGap)
            .id(taskID)
        }

        draftAppendRow

        ForEach(completedTasks) { task in
            let taskID = task.id
            let isBeingCleared = iState.clearingTaskIDs.contains(taskID)
            TaskRowView(
                task: task,
                taskID: taskID,
                isSelected: fState.selectedTaskID == taskID,
                isSwiping: $iState.isSwiping,
                focusedField: $focusedFieldBinding,
                onToggle: { toggleCompletion($0); withAnimation { iState.fetchWorkaround &+= 1 } },
                onTitleChange: { updateTitle($0, $1) },
                onDelete: { deleteTaskWithUndo($0) },
                onSelect: { selectTask($0) }
            )
            .opacity(isBeingCleared ? 0 : 1)
            .offset(y: isBeingCleared ? 40 : 0)
            .padding(.bottom, rowGap)
            .id(taskID)
        }
    }

    var body: some View {
        taskScrollView
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .global).onEnded { value in
                    guard value.location.y > layoutStorage.contentBottomY else { return }
                    handleBackgroundTap()
                }
            )
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
        ZStack(alignment: .top) {
            ScrollView {
              ScrollViewReader { scrollProxy in
                VStack(alignment: .leading, spacing: vStackSpacing) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: pState.headerHeight)
                        pullToCreateIndicatorRow
                    }
                    if isPrependDraftVisible {
                        draftPrependRow
                            .padding(.bottom, rowGap)
                    }
                    taskRows
                }
                .offset(
                    y: isPrependDraftVisible
                        ? pState.frozenOffset
                        : -min(
                            pState.pullToCreate.pullOffset,
                            PullToCreateIndicator.indicatorHeight + rowGap
                        )
                )
                .animation(
                    .spring(response: 0.28, dampingFraction: 1.0),
                    value: pState.frozenOffset
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .onGeometryChange(for: CGFloat.self) {
                    $0.frame(in: .global).maxY
                } action: {
                    layoutStorage.contentBottomY = $0
                }
                .padding(.trailing, 16)
                .padding(.vertical, 12)
                .onChange(of: focusedFieldBinding) { oldValue, newValue in
                    fState.focusedField = newValue
                    handleFocusChange(from: oldValue, to: newValue)

                    if newValue == nil,
                        !iState.isShowingSettings,
                        !iState.isShowingSyncDiagnostics
                    {
                        if let pending = fState.pendingFocus {
                            focusedFieldBinding = pending
                            fState.focusedField = pending
                            fState.pendingFocus = nil
                        } else {
                            focusedFieldBinding = .scrollView
                            fState.focusedField = .scrollView
                        }
                    }

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
            .scrollDisabled(draggedTaskID != nil || iState.isSwiping)
            .scrollBounceBehavior(.always)
            .contentMargins(.bottom, 20)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                max(0, geo.contentOffset.y + geo.contentInsets.top)
            } action: { _, scrollUp in
                pState.scrollUpAmount = scrollUp
            }
            .background {
                Color.outerBackground.ignoresSafeArea()
            }
            .overlay {
                if isCompletelyEmpty && draftPlacement == nil {
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
                isDraftOpen: draftPlacement != nil,
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
            .sensoryFeedback(.impact(weight: .light), trigger: iState.draftCount)

            navigationHeader
                .padding(.top, 12)
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    pState.headerHeight = $0
                }
                .offset(y: -pState.scrollUpAmount)
                .background {
                    Color.outerBackground
                        .offset(y: -pState.scrollUpAmount)
                }
        }
    }
}


