import SwiftUI

extension ItemListViewProtocol {

    // MARK: - Computed Properties

    var activeItems: [ItemEntity] {
        Array(items.filter { !$0.isDeleted && !$0.isCompleted })
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var displayActiveItems: [ItemEntity] {
        guard let visualOrder else {
            return activeItems
        }

        return visualOrder.compactMap { id in
            activeItems.first(where: { $0.id == id })
        }
    }

    var completedItems: [ItemEntity] {
        Array(items.filter { !$0.isDeleted && $0.isCompleted })
            .sorted { $0.completedOrder > $1.completedOrder }
    }

    var allItemsInDisplayOrder: [ItemEntity] {
        displayActiveItems + completedItems
    }

    var editingItemID: UUID? {
        if case .item(let id) = focusedField {
            return id
        }
        return nil
    }

    var draggedItemID: UUID? {
        if case .dragging(let id, _) = dragState {
            return id
        }
        return nil
    }

    var visualOrder: [UUID]? {
        if case .dragging(_, let order) = dragState {
            return order
        }
        return nil
    }

    func presentStoreError(_ error: Error) {
        syncMonitor.ingest(error: error)
    }

    private func isLastActiveItem(_ itemID: UUID) -> Bool {
        guard let lastItem = activeItems.last else { return false }
        return lastItem.id == itemID
    }

    func draftID(for placement: DraftItemPlacement) -> UUID {
        switch placement {
        case .prepend:
            draftPrependRowID
        case .append:
            draftAppendRowID
        }
    }

    func draftPlacement(for itemID: UUID) -> DraftItemPlacement? {
        switch itemID {
        case draftPrependRowID:
            .prepend
        case draftAppendRowID:
            .append
        default:
            nil
        }
    }

    // MARK: - Item Creation

    func createNewItemAtTop() -> UUID {
        revealDraftItem(at: .prepend)
        return draftPrependRowID
    }

    func createNewItem() {
        revealDraftItem(at: .append)
    }

    func revealDraftItem(at placement: DraftItemPlacement) {
        if draftPlacement != placement, draftPlacement != nil {
            commitDraftItem()
        }

        clearDragState()
        let itemID = draftID(for: placement)
        draftTitle = ""
        draftPlacement = placement
        fState.pendingFocus = .item(itemID)
        focusedField = .item(itemID)
        fState.selectedItemID = itemID
    }

    func beginDraftItemEditing(_ placement: DraftItemPlacement) {
        guard draftPlacement == placement else { return }
        let itemID = draftID(for: placement)
        fState.selectedItemID = itemID
        if case .item(let id) = fState.pendingFocus, id == itemID {
            fState.pendingFocus = nil
        }
    }

    func commitDraftItem(shouldCreateNewItem: Bool = false) {
        guard let placement = draftPlacement else { return }
        let itemID = draftID(for: placement)
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clear fState.pendingFocus before clearDraftItemUI so that the iOS
        // onChange(of: focusedFieldBinding) nil-redirect doesn't re-focus
        // the draft row via a stale fState.pendingFocus value.
        if case .item(let id) = fState.pendingFocus, id == itemID {
            fState.pendingFocus = nil
        }

        clearDraftItemUI(at: placement, hasTitle: !title.isEmpty)

        if fState.selectedItemID == itemID {
            fState.selectedItemID = nil
        }

        guard !title.isEmpty else { return }

        do {
            let item = switch placement {
            case .prepend:
                try store.createItem(title: title, atBeginning: true)
            case .append:
                try store.createItem(title: title)
            }
            try store.save()
            if placement == .append {
                fState.selectedItemID = item.id
            }
        } catch {
            presentStoreError(error)
        }

        if shouldCreateNewItem, placement == .append {
            revealDraftItem(at: .append)
        }
    }

    func createItem(title: String, afterItemID: UUID) {
        clearDragState()
        do {
            let sortOrder = try sortOrderAfter(itemID: afterItemID)
            let newItem = try store.createItem(title: title, sortOrder: sortOrder)
            try store.save()
            fState.selectedItemID = newItem.id
            focusedField = .scrollView
        } catch {
            presentStoreError(error)
        }
    }

    private func sortOrderAfter(itemID: UUID) throws -> Int64? {
        guard let afterIndex = activeItems.firstIndex(where: { $0.id == itemID }) else {
            return nil
        }
        let afterItem = activeItems[afterIndex]
        if afterIndex + 1 < activeItems.count {
            let nextItem = activeItems[afterIndex + 1]
            let midpoint = (afterItem.sortOrder + nextItem.sortOrder) / 2
            if midpoint == afterItem.sortOrder {
                // Consecutive sort orders leave no room; re-normalise with 1000-unit gaps
                // then recompute. Core Data's identity map ensures afterItem/nextItem reflect
                // the updated values immediately after normalisation.
                try store.normalizeSortOrders()
                return (afterItem.sortOrder + nextItem.sortOrder) / 2
            }
            return midpoint
        } else {
            return afterItem.sortOrder + 1000
        }
    }

    // MARK: - Interaction Handlers

    func handleBackgroundTap() {
        let isItemFocused = if case .item = focusedField { true } else { false }

        if isItemFocused || fState.selectedItemID != nil {
            fState.pendingFocus = nil
            if draftPlacement != nil {
                commitDraftItem()
            }
            fState.selectedItemID = nil
            focusedField = nil
        } else {
            revealDraftItem(at: .append)
        }
    }

    func handleFocusChange(from oldValue: FocusField?, to newValue: FocusField?) {
        let oldID = itemID(from: oldValue)
        let newID = itemID(from: newValue)

        guard oldID != newID, let oldID else {
            return
        }

        if draftPlacement(for: oldID) != nil {
            return
        }

        deleteIfEmpty(itemID: oldID)
    }

    private func itemID(from field: FocusField?) -> UUID? {
        guard case .item(let id) = field else { return nil }
        return id
    }

    private func deleteIfEmpty(itemID: UUID) {
        if case .item(let pendingItemID) = fState.pendingFocus, pendingItemID == itemID {
            return
        }

        guard let item = items.first(where: { $0.id == itemID }) else {
            return
        }
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty else { return }

        managedObjectContext.undoManager?.removeAllActions(withTarget: item)
        managedObjectContext.undoManager?.disableUndoRegistration()
        deleteItem(item)
        managedObjectContext.undoManager?.enableUndoRegistration()
    }

    func updateTitle(_ item: ItemEntity, _ title: String) {
        guard item.title != title else { return }
        do {
            try store.updateWithoutSaving(itemID: item.id, title: title)
        } catch {
            presentStoreError(error)
        }
    }

    func toggleCompletion(_ item: ItemEntity) {
        do {
            if item.isCompleted {
                try store.uncomplete(itemID: item.id)
            } else {
                try store.complete(itemID: item.id)
            }
        } catch {
            presentStoreError(error)
        }
    }

    func handleSwipeComplete(_ itemID: UUID) {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        toggleCompletion(item)
    }

    func handleSwipeDelete(_ itemID: UUID) {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        deleteItem(item)
    }

    func selectItem(
        _ itemID: UUID,
        extendSelection: Bool = false,
        toggleSelection: Bool = false
    ) {
        if toggleSelection {
            fState.toggleSelection(
                itemID: itemID,
                displayOrder: allItemsInDisplayOrder.map(\.id)
            )
        } else if extendSelection && fState.selectedItemID != nil {
            if fState.anchorItemID == nil {
                fState.anchorItemID = fState.cursorItemID
            }
            fState.extendSelection(
                to: itemID,
                displayOrder: allItemsInDisplayOrder.map(\.id)
            )
        } else {
            fState.selectedItemID = itemID
        }
    }

    func deleteItem(_ item: ItemEntity) {
        guard !item.isDeleted else { return }
        let itemID = item.id
        do {
            try store.delete(itemID: itemID)
            if fState.selectedItemID == itemID {
                fState.selectedItemID = nil
            }
        } catch {
            presentStoreError(error)
        }
    }

    func clearCompletedItems() {
        for item in completedItems.reversed() {
            do {
                try store.delete(itemID: item.id)
            } catch {
                presentStoreError(error)
            }
        }
    }

    // MARK: - Keyboard Navigation

    func navigateUp() -> KeyPress.Result {
        guard focusedField == .scrollView else {
            return .ignored
        }

        guard let currentID = fState.selectedItemID else {
            fState.selectedItemID = activeItems.last?.id
            return .handled
        }

        let displayOrder = allItemsInDisplayOrder
        guard let currentIndex = displayOrder.firstIndex(where: { $0.id == currentID }) else {
            return .handled
        }

        if currentIndex > 0 {
            fState.selectedItemID = displayOrder[currentIndex - 1].id
        }
        return .handled
    }

    func navigateDown() -> KeyPress.Result {
        guard focusedField == .scrollView else {
            return .ignored
        }

        guard let currentID = fState.selectedItemID else {
            fState.selectedItemID = activeItems.first?.id ?? completedItems.first?.id
            return .handled
        }

        let displayOrder = allItemsInDisplayOrder
        guard let currentIndex = displayOrder.firstIndex(where: { $0.id == currentID }) else {
            return .handled
        }

        if currentIndex < displayOrder.count - 1 {
            fState.selectedItemID = displayOrder[currentIndex + 1].id
        }
        return .handled
    }

    func navigateUpExtend() -> KeyPress.Result {
        guard focusedField == .scrollView else {
            return .ignored
        }

        let displayOrder = allItemsInDisplayOrder.map(\.id)

        // If nothing is selected yet, start single-select at the bottom.
        guard let cursorID = fState.cursorItemID else {
            fState.selectedItemID = activeItems.last?.id
            return .handled
        }

        guard let cursorIndex = displayOrder.firstIndex(of: cursorID),
            cursorIndex > 0
        else {
            return .handled
        }

        let targetID = displayOrder[cursorIndex - 1]
        // On the first extend, the anchor is wherever the cursor is.
        if !fState.hasMultipleSelection {
            fState.anchorItemID = cursorID
        }
        fState.extendSelection(to: targetID, displayOrder: displayOrder)
        return .handled
    }

    func navigateDownExtend() -> KeyPress.Result {
        guard focusedField == .scrollView else {
            return .ignored
        }

        let displayOrder = allItemsInDisplayOrder.map(\.id)

        guard let cursorID = fState.cursorItemID else {
            fState.selectedItemID = activeItems.first?.id ?? completedItems.first?.id
            return .handled
        }

        guard let cursorIndex = displayOrder.firstIndex(of: cursorID),
            cursorIndex < displayOrder.count - 1
        else {
            return .handled
        }

        let targetID = displayOrder[cursorIndex + 1]
        if !fState.hasMultipleSelection {
            fState.anchorItemID = cursorID
        }
        fState.extendSelection(to: targetID, displayOrder: displayOrder)
        return .handled
    }

    func toggleSelectedItem() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }
        let ids = fState.selectedItemIDs
        guard !ids.isEmpty else { return .handled }
        let itemsToToggle = allItemsInDisplayOrder.filter { ids.contains($0.id) }
        guard !itemsToToggle.isEmpty else { return .handled }
        let hasActive = itemsToToggle.contains { !$0.isCompleted }
        let hasCompleted = itemsToToggle.contains { $0.isCompleted }
        guard !(hasActive && hasCompleted) else { return .handled }
        for item in itemsToToggle {
            toggleCompletion(item)
        }
        return .handled
    }

    func focusSelectedItem() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }
        guard !fState.hasMultipleSelection else { return .handled }
        guard let currentID = fState.selectedItemID else { return .handled }
        guard let item = allItemsInDisplayOrder.first(where: { $0.id == currentID }) else {
            return .handled
        }
        guard !item.isCompleted else { return .handled }
        startEditing(currentID)
        return .handled
    }

    func deleteSelectedItem() -> KeyPress.Result {
        guard focusedField == .scrollView else {
            return .ignored
        }
        let ids = fState.selectedItemIDs
        guard !ids.isEmpty else { return .handled }
        let displayOrder = allItemsInDisplayOrder
        let itemsToDelete = displayOrder.filter { ids.contains($0.id) }
        guard !itemsToDelete.isEmpty else { return .handled }

        // Find the next item after the last selected one to move selection to.
        let lastSelectedIndex = displayOrder.lastIndex(where: { ids.contains($0.id) })
        let nextItem = lastSelectedIndex.flatMap { idx in
            displayOrder.dropFirst(idx + 1).first(where: { !ids.contains($0.id) })
        }

        fState.selectedItemID = nil
        for item in itemsToDelete {
            deleteItem(item)
        }
        if let nextItem {
            fState.selectedItemID = nextItem.id
        }
        return .handled
    }

    func moveSelectedItemUp() {
        guard focusedField == .scrollView else { return }
        guard let currentID = fState.selectedItemID else { return }
        guard let currentIndex = activeItems.firstIndex(where: { $0.id == currentID }) else { return }
        guard currentIndex > 0 else { return }

        do {
            try store.moveItem(itemID: currentID, toIndex: currentIndex - 1)
        } catch {
            presentStoreError(error)
        }
    }

    func moveSelectedItemDown() {
        guard focusedField == .scrollView else { return }
        guard let currentID = fState.selectedItemID else { return }
        guard let currentIndex = activeItems.firstIndex(where: { $0.id == currentID }) else { return }
        guard currentIndex < activeItems.count - 1 else { return }

        do {
            try store.moveItem(itemID: currentID, toIndex: currentIndex + 1)
        } catch {
            presentStoreError(error)
        }
    }

    func markSelectedItemCompleted() {
        guard focusedField == .scrollView else { return }
        let ids = fState.selectedItemIDs
        guard !ids.isEmpty else { return }
        let itemsToToggle = allItemsInDisplayOrder.filter { ids.contains($0.id) }
        for item in itemsToToggle {
            toggleCompletion(item)
        }
    }

    // MARK: - Focus Management

    func focusTextField(_ itemID: UUID) {
        focusedField = .item(itemID)
    }

    func startEditing(_ itemID: UUID) {
        fState.selectedItemID = itemID
        focusedField = .item(itemID)
        fState.pendingFocus = nil
    }

    func endEditing(_ itemID: UUID, shouldCreateNewItem: Bool) {
        if draftPlacement(for: itemID) != nil {
            commitDraftItem(shouldCreateNewItem: shouldCreateNewItem)
            return
        }

        do {
            try store.save()
        } catch {
            presentStoreError(error)
        }

        let wasLastActiveItem = isLastActiveItem(itemID)
        let willBeDeleted = shouldDeleteIfEmpty(itemID: itemID)

        if willBeDeleted {
            fState.selectedItemID = nil
            deleteIfEmpty(itemID: itemID)
        } else if wasLastActiveItem && shouldCreateNewItem {
            revealDraftItem(at: .append)
        } else if shouldCreateNewItem {
            focusedField = .scrollView
        }
    }

    private func shouldDeleteIfEmpty(itemID: UUID) -> Bool {
        guard let item = items.first(where: { $0.id == itemID }) else {
            return false
        }
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty
    }

    // MARK: - Drag and Drop

    func startDrag(itemID: UUID) {
        guard case .idle = dragState else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            dragState = .dragging(id: itemID, order: activeItems.map(\.id))
        }
        didStartDrag()
    }

    func updateVisualOrder(insertBefore targetID: UUID) {
        guard let draggedID = draggedItemID,
            let order = visualOrder
        else { return }

        var newOrder = order.filter { $0 != draggedID }
        if let targetIndex = newOrder.firstIndex(of: targetID) {
            newOrder.insert(draggedID, at: targetIndex)
        }

        if newOrder != order {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                setDragOrder(newOrder)
            }
        }
    }

    func updateVisualOrder(insertAfter targetID: UUID) {
        guard let draggedID = draggedItemID,
            let order = visualOrder
        else { return }

        var newOrder = order.filter { $0 != draggedID }
        if let targetIndex = newOrder.firstIndex(of: targetID) {
            newOrder.insert(draggedID, at: targetIndex + 1)
        }

        if newOrder != order {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                setDragOrder(newOrder)
            }
        }
    }

    func updateVisualOrderSmart(relativeTo targetID: UUID) {
        guard let draggedID = draggedItemID,
            let order = visualOrder
        else { return }

        guard let draggedIndex = order.firstIndex(of: draggedID),
            let targetIndex = order.firstIndex(of: targetID)
        else { return }

        if draggedIndex < targetIndex {
            updateVisualOrder(insertAfter: targetID)
        } else {
            updateVisualOrder(insertBefore: targetID)
        }
    }

    func updateVisualOrder(insertAtEnd: Bool) {
        guard let draggedID = draggedItemID,
            let order = visualOrder
        else { return }

        var newOrder = order.filter { $0 != draggedID }
        newOrder.append(draggedID)

        if newOrder != order {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                setDragOrder(newOrder)
            }
        }
    }

    func commitCurrentDrag() -> Bool {
        guard let droppedUUID = draggedItemID,
            let order = visualOrder,
            let finalIndex = order.firstIndex(of: droppedUUID)
        else {
            clearDragState()
            return false
        }

        do {
            try store.moveItem(itemID: droppedUUID, toIndex: finalIndex)
            clearDragState()
        } catch {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                clearDragState()
            }
            presentStoreError(error)
        }

        return true
    }

    func setDragOrder(_ order: [UUID]) {
        guard case .dragging(let id, _) = dragState else { return }
        dragState = .dragging(id: id, order: order)
    }

    func clearDragState() {
        dragState = .idle
    }
}
