import Foundation
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

@Suite("ItemStore Completion Behavior", .serialized)
@MainActor
struct ItemStoreCompletionTests {

    // MARK: - Basic Completion Tests

    @Test("Complete item")
    func completeItem() async throws {
        let store = makeTestStore()
        let item = try store.createItem(title: "Task to complete")

        try store.complete(itemID: item.id)

        let items = try store.fetchItems()
        #expect(items.first?.isCompleted == true)
    }

    @Test("Uncomplete item")
    func uncompleteItem() async throws {
        let store = makeTestStore()
        let item = try store.createItem(title: "Item")
        try store.complete(itemID: item.id)

        try store.uncomplete(itemID: item.id)

        let items = try store.fetchItems()
        #expect(items.first?.isCompleted == false)
    }

    @Test("Complete with invalid ID does nothing")
    func completeWithInvalidIDDoesNothing() async throws {
        let store = makeTestStore()
        let item = try store.createItem(title: "Item")
        let invalidID = UUID()

        try store.complete(itemID: invalidID)

        let items = try store.fetchItems()
        #expect(items.first?.isCompleted == false)
    }

    @Test("Uncomplete with invalid ID does nothing")
    func uncompleteWithInvalidIDDoesNothing() async throws {
        let store = makeTestStore()
        let item = try store.createItem(title: "Item")
        try store.complete(itemID: item.id)
        let invalidID = UUID()

        try store.uncomplete(itemID: invalidID)

        let items = try store.fetchItems()
        #expect(items.first?.isCompleted == true)
    }

    // MARK: - Timestamp Tests

    @Test("Completing item updates timestamp")
    func completingItemUpdatesTimestamp() async throws {
        let store = makeTestStore()
        let item = try store.createItem(title: "Item")
        let originalUpdatedAt = item.updatedAt

        // Small delay to ensure timestamp difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        try store.complete(itemID: item.id)

        let items = try store.fetchItems()
        let updatedItem = items.first
        #expect(updatedItem?.updatedAt ?? Date() > originalUpdatedAt)
    }

    // MARK: - Sorting Tests

    @Test("Active items appear before completed items")
    func activeItemsAppearBeforeCompletedItems() async throws {
        let store = makeTestStore()
        let item1 = try store.createItem(title: "Item 1")
        let item2 = try store.createItem(title: "Item 2")
        let item3 = try store.createItem(title: "Item 3")

        try store.complete(itemID: item2.id)

        let items = try store.fetchItems()
        #expect(items[0].id == item1.id)
        #expect(items[1].id == item3.id)
        #expect(items[2].id == item2.id)
    }

    @Test("Completed items sorted by completedOrder")
    func completedItemsSortedByCompletedOrder() async throws {
        let store = makeTestStore()
        let item1 = try store.createItem(title: "Item 1")
        let item2 = try store.createItem(title: "Item 2")
        let item3 = try store.createItem(title: "Item 3")

        // Complete in specific order
        try store.complete(itemID: item2.id)
        try store.complete(itemID: item1.id)
        try store.complete(itemID: item3.id)

        let items = try store.fetchItems()
        // All completed, should be sorted by completedOrder (most recently completed first)
        #expect(items[0].id == item3.id)
        #expect(items[1].id == item1.id)
        #expect(items[2].id == item2.id)
    }

    @Test("Toggle completion multiple times")
    func toggleCompletionMultipleTimes() async throws {
        let store = makeTestStore()
        let item = try store.createItem(title: "Item")

        try store.complete(itemID: item.id)
        var items = try store.fetchItems()
        #expect(items.first?.isCompleted == true)

        try store.uncomplete(itemID: item.id)
        items = try store.fetchItems()
        #expect(items.first?.isCompleted == false)

        try store.complete(itemID: item.id)
        items = try store.fetchItems()
        #expect(items.first?.isCompleted == true)
    }

    @Test("Complete all items")
    func completeAllItems() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 5)

        for id in itemIDs {
            try store.complete(itemID: id)
        }

        let items = try store.fetchItems()
        #expect(items.allSatisfy { $0.isCompleted })
        #expect(items.count == 5)
    }

    @Test("Uncomplete restores previous sortOrder when no active conflict")
    func uncompleteRestoresPreviousSortOrderWhenNoConflict() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 3)
        let itemToRestoreID = itemIDs[1]

        let originalSortOrder = try store.fetchItems().first { $0.id == itemToRestoreID }?.sortOrder
        #expect(originalSortOrder != nil)

        try store.complete(itemID: itemToRestoreID)
        try store.uncomplete(itemID: itemToRestoreID)

        let activeItems = try store.fetchItems().filter { !$0.isCompleted }
        let restoredItem = activeItems.first { $0.id == itemToRestoreID }

        #expect(restoredItem != nil)
        #expect(restoredItem?.sortOrder == originalSortOrder)
        #expect(activeItems.count == 3)
    }

    @Test("Uncomplete appends item when restored sortOrder conflicts with active item")
    func uncompleteAppendsWhenRestoredSortOrderConflicts() async throws {
        let store = makeTestStore()
        let activeItem = try store.createItem(title: "Active item")
        let completedItem = try store.createItem(title: "Completed item")

        try store.complete(itemID: completedItem.id)
        try store.moveItem(itemID: activeItem.id, toIndex: 0)
        completedItem.sortOrder = activeItem.sortOrder
        try store.save()

        try store.uncomplete(itemID: completedItem.id)

        let activeItems = try store.fetchItems().filter { !$0.isCompleted }
            .sorted { $0.sortOrder < $1.sortOrder }
        let lastActiveItem = activeItems.last

        #expect(activeItems.count == 2)
        #expect(lastActiveItem?.id == completedItem.id)
        #expect(lastActiveItem?.sortOrder ?? 0 > activeItem.sortOrder)
    }
}
