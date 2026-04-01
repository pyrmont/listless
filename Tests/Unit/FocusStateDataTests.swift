import Foundation
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

@Suite("FocusStateData Selection", .serialized)
@MainActor
struct FocusStateDataSelectionTests {

    // Five stable IDs used across tests, representing display order.
    static let ids = (0..<5).map { _ in UUID() }
    static var displayOrder: [UUID] { ids }

    // MARK: - selectedItemID (single-select setter/getter)

    @Test("selectedItemID setter establishes single selection")
    func selectedItemIDSetter() {
        var state = FocusStateData()
        let id = Self.ids[2]

        state.selectedItemID = id

        #expect(state.selectedItemID == id)
        #expect(state.cursorItemID == id)
        #expect(state.anchorItemID == id)
        #expect(state.selectedItemIDs == [id])
        #expect(state.inactiveSelections.isEmpty)
    }

    @Test("selectedItemID setter clears selection when set to nil")
    func selectedItemIDSetterNil() {
        var state = FocusStateData()
        state.selectedItemID = Self.ids[0]

        state.selectedItemID = nil

        #expect(state.selectedItemID == nil)
        #expect(state.cursorItemID == nil)
        #expect(state.anchorItemID == nil)
        #expect(state.selectedItemIDs.isEmpty)
        #expect(state.inactiveSelections.isEmpty)
    }

    // MARK: - isItemSelected / hasMultipleSelection

    @Test("isItemSelected returns true only for selected items")
    func isItemSelected() {
        var state = FocusStateData()
        state.selectedItemID = Self.ids[1]

        #expect(state.isItemSelected(Self.ids[1]))
        #expect(!state.isItemSelected(Self.ids[0]))
    }

    @Test("hasMultipleSelection is false for single selection")
    func hasMultipleSelectionSingle() {
        var state = FocusStateData()
        state.selectedItemID = Self.ids[0]

        #expect(!state.hasMultipleSelection)
    }

    // MARK: - selectAll

    @Test("selectAll selects every item in display order")
    func selectAllBasic() {
        var state = FocusStateData()
        let order = Self.displayOrder

        state.selectAll(displayOrder: order)

        #expect(state.selectedItemIDs == Set(order))
        #expect(state.anchorItemID == order.first)
        #expect(state.cursorItemID == order.last)
        #expect(state.inactiveSelections.isEmpty)
        #expect(state.hasMultipleSelection)
    }

    @Test("selectAll with empty display order does nothing")
    func selectAllEmpty() {
        var state = FocusStateData()
        state.selectedItemID = Self.ids[0]

        state.selectAll(displayOrder: [])

        #expect(state.selectedItemID == Self.ids[0])
    }

    @Test("selectAll with single item sets anchor and cursor to same item")
    func selectAllSingleItem() {
        var state = FocusStateData()
        let single = [Self.ids[0]]

        state.selectAll(displayOrder: single)

        #expect(state.anchorItemID == Self.ids[0])
        #expect(state.cursorItemID == Self.ids[0])
        #expect(state.selectedItemIDs == Set(single))
        #expect(!state.hasMultipleSelection)
    }

    @Test("selectAll clears inactive selections from prior Cmd+Click")
    func selectAllClearsInactive() {
        var state = FocusStateData()
        let order = Self.displayOrder
        // Build up inactive selections via toggleSelection.
        state.toggleSelection(itemID: order[0], displayOrder: order)
        state.toggleSelection(itemID: order[3], displayOrder: order)

        state.selectAll(displayOrder: order)

        #expect(state.inactiveSelections.isEmpty)
        #expect(state.selectedItemIDs == Set(order))
    }

    // MARK: - toggleSelection (Cmd+Click)

    @Test("Toggle adds an unselected item to the selection")
    func toggleAddsItem() {
        var state = FocusStateData()
        let order = Self.displayOrder

        state.toggleSelection(itemID: order[1], displayOrder: order)

        #expect(state.isItemSelected(order[1]))
        #expect(state.selectedItemIDs.count == 1)
    }

    @Test("Toggle removes a selected item from the selection")
    func toggleRemovesItem() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.toggleSelection(itemID: order[1], displayOrder: order)

        state.toggleSelection(itemID: order[1], displayOrder: order)

        #expect(!state.isItemSelected(order[1]))
        #expect(state.selectedItemIDs.isEmpty)
    }

    @Test("Toggle sets anchor to item below toggled item")
    func toggleAnchorBelowToggledItem() {
        var state = FocusStateData()
        let order = Self.displayOrder

        state.toggleSelection(itemID: order[1], displayOrder: order)

        // Item below index 1 is index 2.
        #expect(state.anchorItemID == order[2])
    }

    @Test("Toggle at bottom of list sets anchor to self")
    func toggleAnchorAtBottom() {
        var state = FocusStateData()
        let order = Self.displayOrder

        state.toggleSelection(itemID: order[4], displayOrder: order)

        #expect(state.anchorItemID == order[4])
    }

    @Test("Adding via toggle resets cursor to anchor")
    func toggleAddResetsCursor() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.toggleSelection(itemID: order[0], displayOrder: order)

        state.toggleSelection(itemID: order[3], displayOrder: order)

        // Toggling index 3 sets anchor to index 4; adding resets cursor to anchor.
        #expect(state.cursorItemID == order[4])
    }

    @Test("Deselecting via toggle keeps cursor at its previous position")
    func toggleDeselectKeepsCursor() {
        var state = FocusStateData()
        let order = Self.displayOrder
        // Select two items.
        state.toggleSelection(itemID: order[1], displayOrder: order)
        state.toggleSelection(itemID: order[3], displayOrder: order)
        let cursorBefore = state.cursorItemID

        // Deselect one of them.
        state.toggleSelection(itemID: order[1], displayOrder: order)

        #expect(state.cursorItemID == cursorBefore)
    }

    @Test("Deselecting the last selected item clears all state")
    func toggleDeselectLast() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.toggleSelection(itemID: order[2], displayOrder: order)

        state.toggleSelection(itemID: order[2], displayOrder: order)

        #expect(state.selectedItemIDs.isEmpty)
        #expect(state.anchorItemID == nil)
        #expect(state.cursorItemID == nil)
        #expect(state.inactiveSelections.isEmpty)
    }

    @Test("Toggle with ID not in display order is ignored")
    func toggleUnknownID() {
        var state = FocusStateData()
        let unknown = UUID()

        state.toggleSelection(itemID: unknown, displayOrder: Self.displayOrder)

        #expect(state.selectedItemIDs.isEmpty)
    }

    @Test("Multiple toggles build discontinuous selection")
    func toggleMultipleDiscontinuous() {
        var state = FocusStateData()
        let order = Self.displayOrder

        state.toggleSelection(itemID: order[0], displayOrder: order)
        state.toggleSelection(itemID: order[2], displayOrder: order)
        state.toggleSelection(itemID: order[4], displayOrder: order)

        #expect(state.isItemSelected(order[0]))
        #expect(state.isItemSelected(order[2]))
        #expect(state.isItemSelected(order[4]))
        #expect(!state.isItemSelected(order[1]))
        #expect(!state.isItemSelected(order[3]))
        #expect(state.hasMultipleSelection)
    }

    // MARK: - extendSelection (Shift+Arrow)

    @Test("Extend selection downward from anchor")
    func extendDown() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.selectedItemID = order[1]

        state.extendSelection(to: order[3], displayOrder: order)

        #expect(state.selectedItemIDs == Set(order[1...3]))
        #expect(state.cursorItemID == order[3])
        #expect(state.anchorItemID == order[1])
    }

    @Test("Extend selection upward from anchor")
    func extendUp() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.selectedItemID = order[3]

        state.extendSelection(to: order[1], displayOrder: order)

        #expect(state.selectedItemIDs == Set(order[1...3]))
        #expect(state.cursorItemID == order[1])
        #expect(state.anchorItemID == order[3])
    }

    @Test("Extend selection contracts when cursor moves back toward anchor")
    func extendContract() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.selectedItemID = order[1]

        state.extendSelection(to: order[4], displayOrder: order)
        state.extendSelection(to: order[2], displayOrder: order)

        #expect(state.selectedItemIDs == Set(order[1...2]))
        #expect(state.cursorItemID == order[2])
    }

    @Test("Extend to same position as anchor selects only anchor")
    func extendToAnchor() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.selectedItemID = order[2]

        state.extendSelection(to: order[2], displayOrder: order)

        #expect(state.selectedItemIDs == [order[2]])
        #expect(state.cursorItemID == order[2])
    }

    @Test("Extend without anchor is ignored")
    func extendWithoutAnchor() {
        var state = FocusStateData()

        state.extendSelection(to: Self.ids[2], displayOrder: Self.displayOrder)

        #expect(state.selectedItemIDs.isEmpty)
    }

    @Test("Extend with unknown target ID is ignored")
    func extendUnknownTarget() {
        var state = FocusStateData()
        state.selectedItemID = Self.ids[0]

        state.extendSelection(to: UUID(), displayOrder: Self.displayOrder)

        #expect(state.selectedItemIDs == [Self.ids[0]])
    }

    // MARK: - Cmd+Click then Shift+Arrow (inactive selection preservation)

    @Test("Shift+Arrow after Cmd+Click preserves inactive selections")
    func extendPreservesInactive() {
        var state = FocusStateData()
        let order = Self.displayOrder

        // Cmd+Click items 0 and 4 to create a discontinuous selection.
        state.toggleSelection(itemID: order[0], displayOrder: order)
        state.toggleSelection(itemID: order[4], displayOrder: order)

        // After toggling index 4, anchor is set to index 4 (last item).
        // Shift+Arrow down to index 4 should preserve index 0 as inactive.
        state.extendSelection(to: order[4], displayOrder: order)

        #expect(state.isItemSelected(order[0]))
        #expect(state.isItemSelected(order[4]))
    }

    @Test("Adjacent inactive selections merge into active range")
    func mergeAdjacentInactive() {
        var state = FocusStateData()
        let order = Self.displayOrder

        // Select items 0 and 2 via Cmd+Click.
        state.toggleSelection(itemID: order[0], displayOrder: order)
        state.toggleSelection(itemID: order[2], displayOrder: order)

        // After toggling 0 then 2:
        //   - toggleSelection(0): selected={0}, anchor=1, cursor=1
        //   - toggleSelection(2): selected={0,2}, anchor=3, cursor=3
        //     inactive = {0} (outside anchor(3)–cursor(3) range)

        // Extend from anchor (3) up to 1 — active range is [1,2,3].
        // Item 0 is adjacent to active range at index 1, so it merges.
        state.extendSelection(to: order[1], displayOrder: order)

        #expect(state.isItemSelected(order[0]))
        #expect(state.isItemSelected(order[1]))
        #expect(state.isItemSelected(order[2]))
        #expect(state.isItemSelected(order[3]))
        #expect(state.inactiveSelections.isEmpty)
    }

    @Test("Non-adjacent inactive selections stay inactive")
    func nonAdjacentStaysInactive() {
        var state = FocusStateData()
        let order = Self.displayOrder

        // Select items 0 and 4 via Cmd+Click.
        state.toggleSelection(itemID: order[0], displayOrder: order)
        state.toggleSelection(itemID: order[4], displayOrder: order)

        // After toggling 0 then 4:
        //   - toggleSelection(0): selected={0}, anchor=1, cursor=1
        //   - toggleSelection(4): selected={0,4}, anchor=4, cursor=4
        //     inactive = {0} (outside anchor(4)–cursor(4) range)

        // Extend from anchor (4) to 3 — active range is [3,4].
        // Item 0 is not adjacent to index 3, so stays inactive.
        state.extendSelection(to: order[3], displayOrder: order)

        #expect(state.isItemSelected(order[0]))
        #expect(state.isItemSelected(order[3]))
        #expect(state.isItemSelected(order[4]))
        #expect(!state.isItemSelected(order[1]))
        #expect(!state.isItemSelected(order[2]))
        #expect(state.inactiveSelections.contains(order[0]))
    }

    // MARK: - Display order changes between operations

    @Test("Prune then extend after item is removed from display order")
    func pruneAndExtendAfterItemRemoved() {
        var state = FocusStateData()
        let order = Self.displayOrder

        // Cmd+Click items 1 and 3.
        state.toggleSelection(itemID: order[1], displayOrder: order)
        state.toggleSelection(itemID: order[3], displayOrder: order)
        // State: selected={1,3}, anchor=4, cursor=4, inactive={1,3}

        // Simulate item 3 being deleted — prune stale IDs.
        let reducedOrder = [order[0], order[1], order[2], order[4]]
        state.pruneDeletedItems(displayOrder: reducedOrder)

        // order[3] removed from selected and inactive; anchor/cursor (order[4]) still valid.
        #expect(!state.isItemSelected(order[3]))
        #expect(state.isItemSelected(order[1]))
        #expect(state.anchorItemID == order[4])

        // Extend from anchor (order[4]) toward order[2].
        state.extendSelection(to: order[2], displayOrder: reducedOrder)

        // Active range [order[2], order[4]]; order[1] is adjacent inactive → merges.
        #expect(state.isItemSelected(order[1]))
        #expect(state.isItemSelected(order[2]))
        #expect(state.isItemSelected(order[4]))
        #expect(!state.isItemSelected(order[3]))
        #expect(state.inactiveSelections.isEmpty)
    }

    @Test("Prune then extend when anchor was the deleted item")
    func pruneRemovedAnchorThenExtend() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.selectedItemID = order[2]

        // Remove the anchor/cursor item from display order.
        let reducedOrder = [order[0], order[1], order[3], order[4]]
        state.pruneDeletedItems(displayOrder: reducedOrder)

        // Anchor and cursor pruned; selection is now empty.
        #expect(state.selectedItemIDs.isEmpty)
        #expect(state.anchorItemID == nil)
        #expect(state.cursorItemID == nil)
    }

    @Test("Toggle after display order is reordered uses new positions")
    func toggleWithReorderedDisplay() {
        var state = FocusStateData()
        let order = Self.displayOrder

        // Reverse the display order (simulating a sort change).
        let reversed = Array(order.reversed())

        // Toggle item that was at index 4 in original, now at index 0.
        state.toggleSelection(itemID: order[4], displayOrder: reversed)

        // In reversed order, order[4] is at index 0, so "below" is index 1 = order[3].
        #expect(state.anchorItemID == order[3])
        #expect(state.isItemSelected(order[4]))
    }

    @Test("Prune after selectAll with deleted items cleans up selection")
    func pruneAfterSelectAll() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.selectAll(displayOrder: order)

        // Items 0 and 2 deleted.
        let shrunken = [order[1], order[3], order[4]]
        state.pruneDeletedItems(displayOrder: shrunken)

        #expect(state.selectedItemIDs == Set([order[1], order[3], order[4]]))
        // Anchor (order[0]) was pruned; cursor (order[4]) survives.
        #expect(state.anchorItemID == nil)
        #expect(state.cursorItemID == order[4])
    }

    // MARK: - pruneDeletedItems

    @Test("Prune with no deletions changes nothing")
    func pruneNoOp() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.toggleSelection(itemID: order[1], displayOrder: order)
        state.toggleSelection(itemID: order[3], displayOrder: order)
        let selectedBefore = state.selectedItemIDs
        let inactiveBefore = state.inactiveSelections

        state.pruneDeletedItems(displayOrder: order)

        #expect(state.selectedItemIDs == selectedBefore)
        #expect(state.inactiveSelections == inactiveBefore)
    }

    @Test("Prune removes ghost IDs from selectedItemIDs and inactiveSelections")
    func pruneRemovesGhosts() {
        var state = FocusStateData()
        let order = Self.displayOrder
        // Cmd+Click 0 and 2 to create inactive selection at 0.
        state.toggleSelection(itemID: order[0], displayOrder: order)
        state.toggleSelection(itemID: order[2], displayOrder: order)

        // Delete item 0.
        let reducedOrder = [order[1], order[2], order[3], order[4]]
        state.pruneDeletedItems(displayOrder: reducedOrder)

        #expect(!state.isItemSelected(order[0]))
        #expect(!state.inactiveSelections.contains(order[0]))
        #expect(state.isItemSelected(order[2]))
    }

    @Test("Prune with all items deleted clears everything")
    func pruneAllDeleted() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.selectAll(displayOrder: order)

        state.pruneDeletedItems(displayOrder: [])

        #expect(state.selectedItemIDs.isEmpty)
        #expect(state.anchorItemID == nil)
        #expect(state.cursorItemID == nil)
        #expect(state.inactiveSelections.isEmpty)
    }

    @Test("Prune falls back cursor to anchor when cursor is deleted")
    func pruneCursorFallsBackToAnchor() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.selectedItemID = order[1]
        state.extendSelection(to: order[3], displayOrder: order)
        // anchor=order[1], cursor=order[3]

        // Delete cursor item.
        let reducedOrder = [order[0], order[1], order[2], order[4]]
        state.pruneDeletedItems(displayOrder: reducedOrder)

        #expect(state.cursorItemID == order[1])
        #expect(state.anchorItemID == order[1])
    }

    // MARK: - selectedItemID setter resets multi-select

    @Test("Setting selectedItemID collapses multi-select to single")
    func setterResetsMultiSelect() {
        var state = FocusStateData()
        let order = Self.displayOrder
        state.selectAll(displayOrder: order)

        state.selectedItemID = order[2]

        #expect(state.selectedItemIDs == [order[2]])
        #expect(state.anchorItemID == order[2])
        #expect(state.cursorItemID == order[2])
        #expect(state.inactiveSelections.isEmpty)
        #expect(!state.hasMultipleSelection)
    }
}
