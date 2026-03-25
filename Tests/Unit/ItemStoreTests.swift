import Foundation
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

@Suite("ItemStore CRUD Operations", .serialized)
@MainActor
struct ItemStoreTests {

    // MARK: - Creation Tests

    @Test("Create item with empty title")
    func createItemWithEmptyTitle() async throws {
        let store = makeTestStore()

        let item = try store.createItem()

        #expect(item.title == "")
        #expect(item.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(item.isCompleted == false)
        #expect(item.createdAt.timeIntervalSinceNow > -1.0)
    }

    @Test("Create item with title")
    func createItemWithTitle() async throws {
        let store = makeTestStore()

        let item = try store.createItem(title: "Buy groceries")

        #expect(item.title == "Buy groceries")
        #expect(item.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
    }

    @Test("Create multiple items with unique IDs")
    func createMultipleItemsWithUniqueIDs() async throws {
        let store = makeTestStore()

        let item1 = try store.createItem(title: "Item 1")
        let item2 = try store.createItem(title: "Item 2")
        let item3 = try store.createItem(title: "Item 3")

        #expect(item1.id != item2.id)
        #expect(item2.id != item3.id)
        #expect(item1.id != item3.id)
    }

    @Test("Created item has timestamps")
    func createdItemHasTimestamps() async throws {
        let store = makeTestStore()

        let beforeCreate = Date()
        let item = try store.createItem(title: "Test")
        let afterCreate = Date()

        #expect(item.createdAt >= beforeCreate)
        #expect(item.createdAt <= afterCreate)
        #expect(item.updatedAt >= beforeCreate)
        #expect(item.updatedAt <= afterCreate)
    }

    @Test("Create item at beginning prepends to active items")
    func createItemAtBeginningPrepends() async throws {
        let store = makeTestStore()

        let first = try store.createItem(title: "First")
        let second = try store.createItem(title: "Second")
        let prepended = try store.createItem(title: "Prepended", atBeginning: true)

        let items = try store.fetchItems().filter { !$0.isCompleted }

        #expect(items.map(\.title) == ["Prepended", "First", "Second"])
        #expect(prepended.sortOrder < first.sortOrder)
        #expect(first.sortOrder < second.sortOrder)
    }

    // MARK: - Fetch Tests

    @Test("Fetch items from empty store")
    func fetchItemsFromEmptyStore() async throws {
        let store = makeTestStore()

        let items = try store.fetchItems()

        #expect(items.isEmpty)
    }

    @Test("Fetch items returns created items")
    func fetchItemsReturnsCreatedItems() async throws {
        let store = makeTestStore()
        _ = try store.createItem(title: "Item 1")
        _ = try store.createItem(title: "Item 2")

        let items = try store.fetchItems()

        #expect(items.count == 2)
        #expect(items[0].title == "Item 1")
        #expect(items[1].title == "Item 2")
    }

    // MARK: - Update Tests

    @Test("Update item title")
    func updateItemTitle() async throws {
        let store = makeTestStore()
        let item = try store.createItem(title: "Original")

        try store.update(itemID: item.id, title: "Updated")

        let items = try store.fetchItems()
        #expect(items.first?.title == "Updated")
    }

    @Test("Update item title without saving")
    func updateItemTitleWithoutSaving() async throws {
        let store = makeTestStore()
        let item = try store.createItem(title: "Original")

        try store.updateWithoutSaving(itemID: item.id, title: "Updated")

        let items = try store.fetchItems()
        #expect(items.first?.title == "Updated")
    }

    @Test("Update with invalid ID does nothing")
    func updateWithInvalidIDDoesNothing() async throws {
        let store = makeTestStore()
        _ = try store.createItem(title: "Item 1")
        let invalidID = UUID()

        try store.update(itemID: invalidID, title: "Should not exist")

        let items = try store.fetchItems()
        #expect(items.count == 1)
        #expect(items.first?.title == "Item 1")
    }

    // MARK: - Delete Tests

    @Test("Delete item")
    func deleteItem() async throws {
        let store = makeTestStore()
        let item1 = try store.createItem(title: "Item 1")
        let item2 = try store.createItem(title: "Item 2")

        try store.delete(itemID: item1.id)

        let items = try store.fetchItems()
        #expect(items.count == 1)
        #expect(items.first?.id == item2.id)
    }

    @Test("Delete all items")
    func deleteAllItems() async throws {
        let store = makeTestStore()
        let item1 = try store.createItem(title: "Item 1")
        let item2 = try store.createItem(title: "Item 2")

        try store.delete(itemID: item1.id)
        try store.delete(itemID: item2.id)

        let items = try store.fetchItems()
        #expect(items.isEmpty)
    }

    @Test("Delete with invalid ID does nothing")
    func deleteWithInvalidIDDoesNothing() async throws {
        let store = makeTestStore()
        _ = try store.createItem(title: "Item 1")
        let invalidID = UUID()

        try store.delete(itemID: invalidID)

        let items = try store.fetchItems()
        #expect(items.count == 1)
    }

    // MARK: - Edge Cases

    @Test("Task IDs persist across fetches")
    func itemIDsPersistAcrossFetches() async throws {
        let store = makeTestStore()
        let item = try store.createItem(title: "Test")
        let originalID = item.id

        let fetchedItems = try store.fetchItems()
        let fetchedID = fetchedItems.first?.id

        #expect(fetchedID == originalID)
    }

    @Test("Create item increments sortOrder")
    func createItemIncrementsSortOrder() async throws {
        let store = makeTestStore()

        let item1 = try store.createItem(title: "Item 1")
        let item2 = try store.createItem(title: "Item 2")
        let item3 = try store.createItem(title: "Item 3")

        #expect(item2.sortOrder > item1.sortOrder)
        #expect(item3.sortOrder > item2.sortOrder)
        #expect(item2.sortOrder - item1.sortOrder == 1000)
        #expect(item3.sortOrder - item2.sortOrder == 1000)
    }
}
