import SwiftUI
import UniformTypeIdentifiers

struct ItemListView: View, ItemListViewProtocol {
    struct InteractionStateData {
        var dragState: DragState = .idle
        var liftedItemID: UUID?
        var draftPlacement: DraftItemPlacement?
        var draftTitle: String = ""
    }

    @AppStorage("colorTheme") private var colorThemeRaw = 0
    private var colorTheme: ColorTheme { ColorTheme(rawValue: colorThemeRaw) ?? .pilbara }

    @Environment(\.undoManager) var undoManager
    @Environment(\.managedObjectContext) var managedObjectContext

    let store: ItemStore
    let windowCoordinator: WindowCoordinator
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    @FetchRequest(
        sortDescriptors: [],
        animation: .default
    )
    var items: FetchedResults<ItemEntity>
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

    var draftPlacement: DraftItemPlacement? {
        get { iState.draftPlacement }
        nonmutating set { iState.draftPlacement = newValue }
    }

    var draftTitle: String {
        get { iState.draftTitle }
        nonmutating set { iState.draftTitle = newValue }
    }

    var vStackSpacing: CGFloat { 0 }
    var isCompletelyEmpty: Bool { activeItems.isEmpty && completedItems.isEmpty }
    var selectedIndex: Int? {
        guard let currentID = fState.selectedItemID else { return nil }
        return activeItems.firstIndex(where: { $0.id == currentID })
    }

    var canDeleteSelectionFromList: Bool {
        !fState.selectedItemIDs.isEmpty && focusedField == .scrollView
    }

    var canMarkSelectionCompleted: Bool {
        guard focusedField == .scrollView else { return false }
        let selected = allItemsInDisplayOrder.filter { fState.isItemSelected($0.id) }
        guard !selected.isEmpty else { return false }
        let hasActive = selected.contains { !$0.isCompleted }
        let hasCompleted = selected.contains { $0.isCompleted }
        return !(hasActive && hasCompleted)
    }

    var markCompletedMenuTitle: String {
        if fState.hasMultipleSelection {
            let hasCompleted = completedItems.contains(where: { fState.isItemSelected($0.id) })
            return hasCompleted ? "Mark as Incomplete" : "Mark as Complete"
        }
        return completedItems.contains(where: { $0.id == fState.selectedItemID })
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
        return index < activeItems.count - 1
    }

    struct MenuState: Equatable {
        let selectedItemIDs: Set<UUID>
        let isScrollViewFocused: Bool
        let activeItemCount: Int
        let completedItemCount: Int
        let selectedIndex: Int?
    }

    var windowCoordinatorTrigger: MenuState {
        MenuState(
            selectedItemIDs: fState.selectedItemIDs,
            isScrollViewFocused: focusedField == .scrollView,
            activeItemCount: activeItems.count,
            completedItemCount: completedItems.count,
            selectedIndex: selectedIndex
        )
    }

    func updateWindowCoordinator() {
        let coord = windowCoordinator
        coord.newItem = { createNewItem() }
        coord.copySelectedItem = {
            guard let itemID = fState.selectedItemID,
                  let item = allItemsInDisplayOrder.first(where: { $0.id == itemID }) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(item.title, forType: .string)
        }
        coord.cutSelectedItem = {
            guard let itemID = fState.selectedItemID,
                  let item = allItemsInDisplayOrder.first(where: { $0.id == itemID }) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(item.title, forType: .string)
            deleteItem(itemID: itemID)
        }
        coord.pasteAfterSelectedItem = {
            guard let itemID = fState.selectedItemID,
                  let string = NSPasteboard.general.string(forType: .string) else { return }
            createItem(title: string, afterItemID: itemID)
        }
        coord.deleteSelectedItem = { _ = deleteSelectedItem() }
        coord.moveSelectedItemUp = { moveSelectedItemUp() }
        coord.moveSelectedItemDown = { moveSelectedItemDown() }
        coord.markSelectedItemCompleted = { markSelectedItemCompleted() }
        coord.selectAllItems = {
            fState.selectAll(displayOrder: allItemsInDisplayOrder.map(\.id))
        }
        coord.clearCompletedItems = { clearCompletedItems() }
        let inNavMode = focusedField == .scrollView
        let singleSelect = !fState.selectedItemIDs.isEmpty && !fState.hasMultipleSelection
        coord.canSelectAllItems = inNavMode && !allItemsInDisplayOrder.isEmpty
        coord.canCopySelectedItem = singleSelect && inNavMode
        coord.canCutSelectedItem = singleSelect && inNavMode
        coord.canPasteAfterSelectedItem = selectedIndex != nil && singleSelect && inNavMode
        coord.canDeleteSelectedItem = canDeleteSelectionFromList
        coord.canMoveSelectedItemUp = canMoveSelectionUp
        coord.canMoveSelectedItemDown = canMoveSelectionDown
        coord.canMarkSelectedItemCompleted = canMarkSelectionCompleted
        coord.markCompletedTitle = markCompletedMenuTitle
        coord.canClearCompletedItems = !completedItems.isEmpty
    }

    init(store: ItemStore, syncMonitor: CloudKitSyncMonitor, windowCoordinator: WindowCoordinator) {
        self.store = store
        self.syncMonitor = syncMonitor
        self.windowCoordinator = windowCoordinator
    }

    func isRowLifted(_ itemID: UUID) -> Bool {
        iState.liftedItemID == itemID || draggedItemID == itemID
    }

    func revealDraftItemUI(at placement: DraftItemPlacement, animated: Bool = false) {
        let itemID = draftID(for: placement)
        draftPlacement = placement
        fState.pendingFocus = .item(itemID)
        focusedField = .item(itemID)
        fState.selectedItemID = itemID
    }

    func clearDraftItemUI(at placement: DraftItemPlacement, hasTitle _: Bool) {
        if draftPlacement == placement {
            draftPlacement = nil
        }
        draftTitle = ""
        if fState.selectedItemID == draftID(for: placement) {
            fState.selectedItemID = nil
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
                ForEach(Array(displayActiveItems.enumerated()), id: \.element.id) { index, item in
                    let itemID = item.id
                    ItemRowView(
                        item: item,
                        itemID: itemID,
                        index: index,
                        totalItems: displayActiveItems.count,
                        isSelected: fState.isItemSelected(itemID),
                        focusedField: $focusedFieldBinding,
                        onToggle: { handleSwipeComplete($0) },
                        onTitleChange: { updateTitle(itemID: $0, title: $1) },
                        onDelete: { deleteItem(itemID: $0) },
                        onSelect: {
                            let modifiers = NSApp.currentEvent?.modifierFlags ?? []
                            selectItem(
                                $0,
                                extendSelection: modifiers.contains(.shift),
                                toggleSelection: modifiers.contains(.command)
                            )
                        },
                        onStartEdit: { startEditing($0) },
                        onEndEdit: { endEditing($0, shouldCreateNewItem: $1) },
                        onPaste: { createItem(title: $0, afterItemID: itemID) }
                    )
                    .itemDragGesture(
                        isActive: !item.isCompleted,
                        itemID: itemID,
                        onDragStart: {
                            iState.liftedItemID = nil
                            startDrag(itemID: itemID)
                        },
                        onLift: { iState.liftedItemID = itemID },
                        onLiftEnd: {
                            if iState.liftedItemID == itemID { iState.liftedItemID = nil }
                            if draggedItemID == itemID { clearDragState() }
                        }
                    )
                    .scaleEffect(isRowLifted(itemID) ? 1.03 : 1.0)
                    .shadow(
                        color: isRowLifted(itemID) ? .black.opacity(0.2) : .clear,
                        radius: 8, y: 3
                    )
                    .zIndex(isRowLifted(itemID) ? 1 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isRowLifted(itemID))
                    .overlay {
                        if draggedItemID != nil && draggedItemID != itemID {
                            VStack(spacing: 0) {
                                // Top 1/6 - insert BEFORE
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(1)
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: ItemReorderDropDelegate(
                                            onTargeted: { updateVisualOrder(insertBefore: itemID) },
                                            onPerform: { commitCurrentDrag() }
                                        )
                                    )

                                // Middle 2/3 - insert based on direction
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(4)
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: ItemReorderDropDelegate(
                                            onTargeted: { updateVisualOrderSmart(relativeTo: itemID) },
                                            onPerform: { commitCurrentDrag() }
                                        )
                                    )

                                // Bottom 1/6 - insert AFTER
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(1)
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: ItemReorderDropDelegate(
                                            onTargeted: { updateVisualOrder(insertAfter: itemID) },
                                            onPerform: { commitCurrentDrag() }
                                        )
                                    )
                            }
                        }
                    }
                }

                if draftPlacement == .append {
                    let total = max(1, displayActiveItems.count + 1)
                    let index = displayActiveItems.count
                    let accentColor = cachedItemColor(
                        forIndex: index, total: total, theme: colorTheme
                    )
                    let isSelected = fState.isItemSelected(draftAppendRowID)
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
                            onEditingChanged: { editing, shouldCreateNewItem in
                                if editing {
                                    beginDraftItemEditing(.append)
                                } else {
                                    commitDraftItem(
                                        shouldCreateNewItem: shouldCreateNewItem
                                    )
                                }
                            },
                            itemID: draftAppendRowID
                        )
                        .focused(
                            $focusedFieldBinding,
                            equals: .item(draftAppendRowID)
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
                                .strokeBorder(accentColor.opacity(0.40), lineWidth: 2)
                        }
                    }
                    .accessibilityIdentifier("draft-row-append")
                    .id(draftAppendRowID)
                }

                ForEach(completedItems) { item in
                    let itemID = item.id
                    ItemRowView(
                        item: item,
                        itemID: itemID,
                        isSelected: fState.isItemSelected(itemID),
                        focusedField: $focusedFieldBinding,
                        onToggle: { handleSwipeComplete($0) },
                        onTitleChange: { updateTitle(itemID: $0, title: $1) },
                        onDelete: { deleteItem(itemID: $0) },
                        onSelect: {
                            selectItem(
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
                delegate: ItemReorderDropDelegate(
                    onTargeted: {},
                    onPerform: { commitCurrentDrag() }
                )
            )
            .onChange(of: focusedFieldBinding) { _, newValue in
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
        .onDrop(
            of: [UTType.text],
            delegate: ItemReorderDropDelegate(
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
        .accessibilityIdentifier("item-list-scrollview")
        .keyboardNavigation([
            ShortcutKey(key: .upArrow): navigateUp,
            ShortcutKey(key: .downArrow): navigateDown,
            ShortcutKey(key: .upArrow, modifiers: .shift): navigateUpExtend,
            ShortcutKey(key: .downArrow, modifiers: .shift): navigateDownExtend,
            ShortcutKey(key: .home): navigateToFirst,
            ShortcutKey(key: .end): navigateToLast,
            ShortcutKey(key: .pageUp): navigatePageUp,
            ShortcutKey(key: .pageDown): navigatePageDown,
            ShortcutKey(key: .return): focusSelectedItem,
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

private struct ItemReorderDropDelegate: DropDelegate {
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
