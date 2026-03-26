import SwiftUI
import UIKit

struct ItemListView: View, ItemListViewProtocol {
    class LayoutStorage {
        var draggedRowWidth: CGFloat = 0
        var draggedRowFrame: CGRect = .zero
        var contentBottomY: CGFloat = 0
    }

    struct InteractionStateData {
        var dragState: DragState = .idle
        var draftCount: Int = 0
        var isShowingSyncDiagnostics = false
        var isShowingSettings = false
        var clearingItemIDs: Set<UUID> = []
        var undoToast: UndoToastData? = nil
        var isSwiping: Bool = false
        var isShowingRenameAlert = false
        var isShowingDeleteAllAlert = false
        var renameText: String = ""
        var draftPlacement: DraftItemPlacement?
        var draftTitle: String = ""
        var fetchWorkaround: Int = 0

        var isShowingOverlay: Bool {
            isShowingSettings || isShowingSyncDiagnostics || isShowingRenameAlert
        }
    }

    struct PullStateData {
        var pullToCreate = PullToCreateState()
        var pullUpOffset: CGFloat = 0

        var headerHeight: CGFloat = 60
    }

    @AppStorage("headingText") var headingText = "Items"
    @AppStorage("colorTheme") private var colorThemeRaw = 0
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("showFPSOverlay") private var showFPSOverlay = false
    private var colorTheme: ColorTheme { ColorTheme(rawValue: colorThemeRaw) ?? .pilbara }
    @Environment(\.undoManager) var undoManager
    @Environment(\.managedObjectContext) var managedObjectContext

    let store: ItemStore
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    @FetchRequest(
        sortDescriptors: [],
        animation: .default
    )
    var items: FetchedResults<ItemEntity>
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

    var draftPlacement: DraftItemPlacement? {
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


    private var selectedIndex: Int? {
        guard let currentID = fState.selectedItemID else { return nil }
        return activeItems.firstIndex(where: { $0.id == currentID })
    }

    private var canMoveSelectionUp: Bool {
        guard focusedField == .scrollView else { return false }
        guard let index = selectedIndex else { return false }
        return index > 0
    }

    private var canMoveSelectionDown: Bool {
        guard focusedField == .scrollView else { return false }
        guard let index = selectedIndex else { return false }
        return index < activeItems.count - 1
    }

    private struct MenuState: Equatable {
        let selectedItemID: UUID?
        let isScrollViewFocused: Bool
        let activeItemCount: Int
        let completedItemCount: Int
        let selectedIndex: Int?
    }

    private var menuCoordinatorTrigger: MenuState {
        MenuState(
            selectedItemID: fState.selectedItemID,
            isScrollViewFocused: focusedField == .scrollView,
            activeItemCount: activeItems.count,
            completedItemCount: completedItems.count,
            selectedIndex: selectedIndex
        )
    }

    func updateMenuCoordinator() {
        let coord = IOSMenuCoordinator.shared
        coord.newItem = { createNewItem() }
        coord.deleteItem = { _ = deleteSelectedItemWithUndo() }
        coord.moveUp = { moveSelectedItemUp() }
        coord.moveDown = { moveSelectedItemDown() }
        coord.markCompleted = { markSelectedItemCompleted() }
        let inNavMode = focusedField == .scrollView
        coord.canDelete = fState.selectedItemID != nil && inNavMode
        coord.canMoveUp = canMoveSelectionUp
        coord.canMoveDown = canMoveSelectionDown
        coord.canMarkCompleted = fState.selectedItemID != nil && inNavMode
        coord.markCompletedTitle = completedItems.contains(where: { $0.id == fState.selectedItemID })
            ? "Mark as Incomplete" : "Mark as Complete"
    }

    var vStackSpacing: CGFloat { 0 }
    var rowGap: CGFloat { 12 }
    var pullCreateThreshold: CGFloat { 70 }
    var flickThreshold: CGFloat { 500 }
    var isCompletelyEmpty: Bool { activeItems.isEmpty && completedItems.isEmpty }

    init(store: ItemStore, syncMonitor: CloudKitSyncMonitor) {
        self.store = store
        self.syncMonitor = syncMonitor
    }

    func clearDraftItemUI(at placement: DraftItemPlacement, hasTitle: Bool) {
        let clear: () -> Void = {
            if draftPlacement == placement {
                draftPlacement = nil
            }
            draftTitle = ""
            if fState.selectedItemID == draftID(for: placement) {
                fState.selectedItemID = nil
            }

            guard placement == .prepend else { return }

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
        if hapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }

    func showSyncDiagnostics() {
        iState.isShowingSyncDiagnostics = true
    }

    func showSettings() {
        iState.isShowingSettings = true
    }

    func showRenameAlert() {
        iState.renameText = headingText
        iState.isShowingRenameAlert = true
    }

    private func dragScaleEffect() -> CGFloat {
        let liftPoints: CGFloat = 20
        let width = layoutStorage.draggedRowWidth
        guard width > 0 else { return 1.05 }
        return (width + liftPoints) / width
    }

    /// Combined indicator and phantom entry row sharing the same VStack slot.
    /// The phantom's UITextView is created while the indicator is visible
    /// (during the pull), so it's ready when the user releases.
    @ViewBuilder var pullToCreateIndicatorRow: some View {
        let pullOffset = pState.pullToCreate.pullOffset
        let indicatorHeight = PullToCreateIndicator.indicatorHeight
        let indicatorDisplayOffset = pState.pullToCreate.indicatorDisplayOffset(
            threshold: pullCreateThreshold
        )
        let frameHeight: CGFloat = isPrependDraftVisible
            ? 0
            : min(pullOffset, indicatorHeight + rowGap)
        let opacity: Double = isPrependDraftVisible || pullOffset <= 0 ? 0 : 1
        PullToCreateIndicator(
            pullOffset: max(0, indicatorDisplayOffset),
            threshold: pullCreateThreshold
        )
        .frame(
            height: frameHeight,
            alignment: .top
        )
        .opacity(opacity)
    }

    /// The draft row content styled to match a item row. Controlled by the
    /// ZStack in ``pullToCreateIndicatorRow`` rather than its own visibility.
    @ViewBuilder private var draftPrependRow: some View {
        DraftRowView(
            accentColor: itemColor(
                forIndex: 0, total: max(1, displayActiveItems.count + 1), theme: colorTheme
            ),
            isSelected: fState.selectedItemID == draftPrependRowID,
            draftID: draftPrependRowID,
            title: $iState.draftTitle,
            onEditingChanged: { editing, _ in
                DispatchQueue.main.async {
                    if editing {
                        beginDraftItemEditing(.prepend)
                    } else {
                        commitDraftItem()
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
                accentColor: itemColor(
                    forIndex: displayActiveItems.count,
                    total: max(1, displayActiveItems.count + 1),
                    theme: colorTheme
                ),
                isSelected: fState.selectedItemID == draftAppendRowID,
                draftID: draftAppendRowID,
                title: $iState.draftTitle,
                onEditingChanged: { editing, shouldCreateNewItem in
                    DispatchQueue.main.async {
                        if editing {
                            beginDraftItemEditing(.append)
                        } else {
                            commitDraftItem(
                                shouldCreateNewItem: shouldCreateNewItem
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

    @ViewBuilder private var itemRows: some View {
        let _ = iState.fetchWorkaround
        let draftOffset = isPrependDraftVisible ? 1 : 0
        let draftTotal = draftPlacement != nil ? 1 : 0
        ForEach(Array(displayActiveItems.enumerated()), id: \.element.id) { index, item in
            let itemID = item.id
            ItemRowView(
                item: item,
                itemID: itemID,
                index: index + draftOffset,
                totalItems: displayActiveItems.count + draftTotal,
                isSelected: fState.selectedItemID == itemID,
                isDragging: $isDragging,
                isSwiping: $iState.isSwiping,
                isLastActiveItem: index == displayActiveItems.count - 1,
                focusedField: $focusedFieldBinding,
                onToggle: { toggleCompletion($0); withAnimation { iState.fetchWorkaround &+= 1 } },
                onTitleChange: { updateTitle($0, $1) },
                onDelete: { deleteItemWithUndo($0) },
                onSelect: { selectItem($0) },
                onStartEdit: { startEditing($0) },
                onEndEdit: {
                    if fState.selectedItemID == $0 {
                        fState.selectedItemID = nil
                    }
                    endEditing($0, shouldCreateNewItem: $1)
                }
            )
            .scaleEffect(draggedItemID == itemID ? dragScaleEffect() : 1.0)
            .shadow(
                color: draggedItemID == itemID ? .black.opacity(0.3) : .clear,
                radius: 12, y: 4
            )
            .itemDragGesture(
                isActive: !item.isCompleted && focusedFieldBinding != .item(itemID),
                itemID: itemID,
                onDragStart: { width in
                    layoutStorage.draggedRowWidth = width
                    startDrag(itemID: itemID)
                },
                onDragChanged: { point in
                    handleIOSDragChanged(itemID: itemID, point: point)
                },
                onDragEnded: { commitIOSDrag() }
            )
            .background {
                if draggedItemID == itemID {
                    Color.clear
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .global)
                        } action: { frame in
                            layoutStorage.draggedRowFrame = frame
                        }
                }
            }
            .padding(.bottom, rowGap)
            .zIndex(draggedItemID == itemID ? 2 : 1)
            .id(itemID)
        }

        draftAppendRow

        ForEach(completedItems) { item in
            let itemID = item.id
            let isBeingCleared = iState.clearingItemIDs.contains(itemID)
            ItemRowView(
                item: item,
                itemID: itemID,
                isSelected: fState.selectedItemID == itemID,
                isSwiping: $iState.isSwiping,
                focusedField: $focusedFieldBinding,
                onToggle: { toggleCompletion($0); withAnimation { iState.fetchWorkaround &+= 1 } },
                onTitleChange: { updateTitle($0, $1) },
                onDelete: { deleteItemWithUndo($0) },
                onSelect: { selectItem($0) }
            )
            .opacity(isBeingCleared ? 0 : 1)
            .offset(y: isBeingCleared ? 40 : 0)
            .padding(.bottom, rowGap)
            .id(itemID)
        }
    }

    var body: some View {
        itemScrollView
            .overlay(alignment: .topLeading) {
                if showFPSOverlay {
                    FPSOverlay()
                        .padding(.top, -16)
                        .padding(.leading, 8)
                        .allowsHitTesting(false)
                }
            }
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .global).onEnded { value in
                    guard value.location.y > layoutStorage.contentBottomY else { return }
                    handleBackgroundTap()
                }
            )
            .accessibilityIdentifier("item-list-scrollview")
            .background {
                let isEditing = if case .item = focusedFieldBinding { true } else { false }
                KeyCommandBridge(
                    isActive: !isEditing && !iState.isShowingOverlay,
                    onUp: { _ = navigateUp() },
                    onDown: { _ = navigateDown() },
                    onSpace: { _ = toggleSelectedItem() },
                    onReturn: { _ = focusSelectedItem() },
                    onDelete: { _ = deleteSelectedItemWithUndo() }
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
            .sheet(isPresented: $iState.isShowingSyncDiagnostics) {
                NavigationStack {
                    SyncDiagnosticsView(syncMonitor: syncMonitor)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { iState.isShowingSyncDiagnostics = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $iState.isShowingSettings) {
                SettingsView(syncMonitor: syncMonitor)
            }
            .alert("Rename List", isPresented: $iState.isShowingRenameAlert) {
                TextField("List name", text: $iState.renameText)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    let trimmed = iState.renameText
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        headingText = trimmed
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .alert("Delete All", isPresented: $iState.isShowingDeleteAllAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    deleteAllItemsWithUndo()
                }
            } message: {
                Text("Are you sure you want to delete all items? You can undo this action.")
            }
    }

    private var itemScrollView: some View {
        ZStack(alignment: .top) {
            ScrollView {
              ScrollViewReader { scrollProxy in
                VStack(alignment: .leading, spacing: vStackSpacing) {
                    navigationHeader
                        .padding(.bottom, 12)
                    pullToCreateIndicatorRow
                    if isPrependDraftVisible {
                        draftPrependRow
                            .padding(.bottom, rowGap)
                    }
                    itemRows
                }
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
                        !iState.isShowingOverlay
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

                    if case .item(let id) = (newValue ?? fState.focusedField),
                        draggedItemID == nil,
                        id != draftPrependRowID
                    {
                        withAnimation {
                            scrollProxy.scrollTo(id)
                        }
                    }
                }
                .onChange(of: fState.selectedItemID) { _, newID in
                    if let newID, draggedItemID == nil {
                        guard newID != draftPrependRowID else { return }
                        withAnimation {
                            scrollProxy.scrollTo(newID)
                        }
                    }
                }
              }
            }
            .scrollDisabled(draggedItemID != nil || iState.isSwiping)
            .scrollBounceBehavior(.always)
            .contentMargins(.bottom, 20)
            .background {
                Color.outerBackground.ignoresSafeArea()
            }
            .overlay {
                if isCompletelyEmpty && draftPlacement == nil {
                    Text("Pull down to create")
                        .font(ItemRowMetrics.hintSUI)
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                pullToClearIndicatorRow
            }
            .pullGestures(
                pullToCreate: $pState.pullToCreate,
                pullUpOffset: $pState.pullUpOffset,
                isDraftOpen: draftPlacement != nil,
                hasCompletedItems: !completedItems.isEmpty,
                pullCreateThreshold: pullCreateThreshold,
                flickThreshold: flickThreshold,
                pullClearThreshold: pullClearThreshold,
                onCreateItemAtTop: { revealPhantomRow() },
                onClearCompleted: {
                    let ids = Set(completedItems.map(\.id))
                    withAnimation(.easeIn(duration: 0.35)) {
                        iState.clearingItemIDs = ids
                    } completion: {
                        iState.clearingItemIDs = []
                        clearCompletedItemsWithUndo()
                    }
                }
            )
            .sensoryFeedback(.impact(weight: .light), trigger: hapticsEnabled ? iState.draftCount : 0)

        }
    }
}


