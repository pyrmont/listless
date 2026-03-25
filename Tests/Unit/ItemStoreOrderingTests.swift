import Foundation
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

@Suite("ItemStore Task Reordering", .serialized)
@MainActor
struct ItemStoreOrderingTests {

    // MARK: - Initial State Tests

    @Test("Initial sortOrder has 1000-point gaps")
    func initialSortOrderHasThousandPointGaps() async throws {
        let store = makeTestStore()

        let item1 = try store.createItem(title: "Item 1")
        let item2 = try store.createItem(title: "Item 2")
        let item3 = try store.createItem(title: "Item 3")

        let items = try store.fetchItems()

        // All items are active, so they should be the first 3
        #expect(items.count == 3)

        // Verify items are in ascending order
        #expect(items[0].sortOrder < items[1].sortOrder)
        #expect(items[1].sortOrder < items[2].sortOrder)

        // Verify 1000-point gaps between items
        #expect(items[1].sortOrder - items[0].sortOrder == 1000)
        #expect(items[2].sortOrder - items[1].sortOrder == 1000)
    }

    // MARK: - Move Tests (Parameterized)

    @Test("Move item to different positions", arguments: [
        (from: 0, to: 2),
        (from: 2, to: 0),
        (from: 0, to: 1),
        (from: 1, to: 0),
        (from: 1, to: 2),
        (from: 2, to: 1),
    ])
    func moveItemToDifferentPositions(from: Int, to: Int) async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 3)
        let itemToMove = itemIDs[from]

        try store.moveItem(itemID: itemToMove, toIndex: to)

        let items = try store.fetchItems().filter { !$0.isCompleted }
        #expect(items[to].id == itemToMove)
    }

    // MARK: - Order Preservation Tests

    @Test("Moving maintains 1000-point gaps")
    func movingMaintainsThousandPointGaps() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 4)

        try store.moveItem(itemID: itemIDs[0], toIndex: 2)

        let items = try store.fetchItems().filter { !$0.isCompleted }
        #expect(items[0].sortOrder == 0)
        #expect(items[1].sortOrder == 1000)
        #expect(items[2].sortOrder == 2000)
        #expect(items[3].sortOrder == 3000)
    }

    @Test("Move item to same index does nothing")
    func moveItemToSameIndexDoesNothing() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 3)
        let originalItems = try store.fetchItems().filter { !$0.isCompleted }

        try store.moveItem(itemID: itemIDs[1], toIndex: 1)

        let items = try store.fetchItems().filter { !$0.isCompleted }
        #expect(items[0].id == originalItems[0].id)
        #expect(items[1].id == originalItems[1].id)
        #expect(items[2].id == originalItems[2].id)
    }

    // MARK: - Invalid Input Tests

    @Test("Move with invalid ID does nothing")
    func moveWithInvalidIDDoesNothing() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 3)
        let originalItems = try store.fetchItems().filter { !$0.isCompleted }
        let invalidID = UUID()

        try store.moveItem(itemID: invalidID, toIndex: 0)

        let items = try store.fetchItems().filter { !$0.isCompleted }
        #expect(items[0].id == originalItems[0].id)
        #expect(items[1].id == originalItems[1].id)
        #expect(items[2].id == originalItems[2].id)
    }

    @Test("Move to negative index clamps to 0")
    func moveToNegativeIndexClampsToZero() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 3)

        try store.moveItem(itemID: itemIDs[2], toIndex: -5)

        let items = try store.fetchItems().filter { !$0.isCompleted }
        #expect(items[0].id == itemIDs[2])
    }

    @Test("Move to out-of-bounds index clamps to end")
    func moveToOutOfBoundsIndexClampsToEnd() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 3)

        try store.moveItem(itemID: itemIDs[0], toIndex: 999)

        let items = try store.fetchItems().filter { !$0.isCompleted }
        #expect(items[2].id == itemIDs[0])
    }

    // MARK: - Completed Task Tests

    @Test("Moving only affects active items")
    func movingOnlyAffectsActiveItems() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 4)
        try store.complete(itemID: itemIDs[3])

        try store.moveItem(itemID: itemIDs[0], toIndex: 2)

        let allItems = try store.fetchItems()
        let activeItems = allItems.filter { !$0.isCompleted }
        let completedItems = allItems.filter { $0.isCompleted }

        #expect(activeItems.count == 3)
        #expect(completedItems.count == 1)
        #expect(completedItems[0].id == itemIDs[3])
    }

    @Test("Moving completed item does nothing")
    func movingCompletedItemDoesNothing() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 3)
        try store.complete(itemID: itemIDs[0])
        let originalItems = try store.fetchItems()

        try store.moveItem(itemID: itemIDs[0], toIndex: 1)

        let items = try store.fetchItems()
        #expect(items[0].id == originalItems[0].id)
        #expect(items[1].id == originalItems[1].id)
        #expect(items[2].id == originalItems[2].id)
    }

    // MARK: - Edge Cases

    @Test("Move single item does nothing")
    func moveSingleItemDoesNothing() async throws {
        let store = makeTestStore()
        let item = try store.createItem(title: "Only item")

        try store.moveItem(itemID: item.id, toIndex: 0)

        let items = try store.fetchItems()
        #expect(items.count == 1)
        #expect(items[0].id == item.id)
    }

    @Test("Move in empty store does nothing")
    func moveInEmptyStoreDoesNothing() async throws {
        let store = makeTestStore()
        let randomID = UUID()

        try store.moveItem(itemID: randomID, toIndex: 0)

        let items = try store.fetchItems()
        #expect(items.isEmpty)
    }

    @Test("Multiple moves maintain order")
    func multipleMoveMaintainOrder() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 4)

        try store.moveItem(itemID: itemIDs[0], toIndex: 3)
        try store.moveItem(itemID: itemIDs[2], toIndex: 0)

        let items = try store.fetchItems().filter { !$0.isCompleted }
        #expect(items[0].id == itemIDs[2])
        #expect(items[3].id == itemIDs[0])
    }
}
