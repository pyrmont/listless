import Foundation
import CoreData
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

@Suite("ItemStore Edge Cases", .serialized)
@MainActor
struct ItemStoreEdgeCaseTests {

    // MARK: - Title Edge Cases

    @Test("Task with empty title")
    func itemWithEmptyTitle() async throws {
        let store = makeTestStore()

        let item = try store.createItem(title: "")

        let items = try store.fetchItems()
        #expect(items.first?.title == "")
    }

    @Test("Task with very long title")
    func itemWithVeryLongTitle() async throws {
        let store = makeTestStore()
        let longTitle = String(repeating: "A", count: 10_000)

        let item = try store.createItem(title: longTitle)

        let items = try store.fetchItems()
        #expect(items.first?.title.count == 10_000)
    }

    @Test("Task with special characters")
    func itemWithSpecialCharacters() async throws {
        let store = makeTestStore()
        let specialTitle = "Test 🎉 with émojis & spëcial çharacters! @#$%^&*()"

        let item = try store.createItem(title: specialTitle)

        let items = try store.fetchItems()
        #expect(items.first?.title == specialTitle)
    }

    @Test("Task with newlines and tabs")
    func itemWithNewlinesAndTabs() async throws {
        let store = makeTestStore()
        let multilineTitle = "Line 1\nLine 2\tTabbed"

        let item = try store.createItem(title: multilineTitle)

        let items = try store.fetchItems()
        #expect(items.first?.title == multilineTitle)
    }

    // MARK: - Large Data Sets

    @Test("Create many items")
    func createManyItems() async throws {
        let store = makeTestStore()
        let count = 100

        for i in 0..<count {
            _ = try store.createItem(title: "Task \(i)")
        }

        let items = try store.fetchItems()
        #expect(items.count == count)
    }

    @Test("Delete all items from large set")
    func deleteAllItemsFromLargeSet() async throws {
        let store = makeTestStore()
        var itemIDs: [UUID] = []

        for i in 0..<50 {
            let item = try store.createItem(title: "Task \(i)")
            itemIDs.append(item.id)
        }

        for id in itemIDs {
            try store.delete(itemID: id)
        }

        let items = try store.fetchItems()
        #expect(items.isEmpty)
    }

    // MARK: - State Transitions

    @Test("Create item after completing all items")
    func createItemAfterCompletingAllItems() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 3)

        for id in itemIDs {
            try store.complete(itemID: id)
        }

        let newItem = try store.createItem(title: "New item")

        let items = try store.fetchItems()
        let activeItems = items.filter { !$0.isCompleted }
        #expect(activeItems.count == 1)
        #expect(activeItems[0].id == newItem.id)
    }

    @Test("Rapid updates to same item")
    func rapidUpdatesToSameItem() async throws {
        let store = makeTestStore()
        let item = try store.createItem(title: "Original")

        for i in 0..<10 {
            try store.update(itemID: item.id, title: "Update \(i)")
        }

        let items = try store.fetchItems()
        #expect(items.first?.title == "Update 9")
    }

    // MARK: - Store State Tests

    @Test("Store with only completed items")
    func storeWithOnlyCompletedItems() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 5)

        for id in itemIDs {
            try store.complete(itemID: id)
        }

        let items = try store.fetchItems()
        #expect(items.allSatisfy { $0.isCompleted })
        #expect(items.count == 5)
    }

    @Test("SortOrder after completing all items")
    func sortOrderAfterCompletingAllItems() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 3)

        for id in itemIDs {
            try store.complete(itemID: id)
        }

        let newItem1 = try store.createItem(title: "New 1")
        let newItem2 = try store.createItem(title: "New 2")

        let activeItems = try store.fetchItems().filter { !$0.isCompleted }
        #expect(activeItems[0].id == newItem1.id)
        #expect(activeItems[1].id == newItem2.id)
        #expect(activeItems[1].sortOrder > activeItems[0].sortOrder)
    }

    @Test("Uncompleting item moves it back to active")
    func uncompletingItemMovesItBackToActive() async throws {
        let (store, itemIDs) = try makeTestStoreWithItems(count: 3)
        try store.complete(itemID: itemIDs[1])

        try store.uncomplete(itemID: itemIDs[1])

        let items = try store.fetchItems()
        let activeItems = items.filter { !$0.isCompleted }
        #expect(activeItems.count == 3)
        #expect(activeItems.contains { $0.id == itemIDs[1] })
    }

    @Test("Uncomplete legacy sortOrder zero conflict appends to end")
    func uncompleteLegacyZeroConflictAppendsToEnd() async throws {
        let store = makeTestStore()
        let activeItem = try store.createItem(title: "Active")
        let completedItem = try store.createItem(title: "Completed")

        activeItem.sortOrder = 0
        try store.complete(itemID: completedItem.id)
        completedItem.sortOrder = 0
        try store.save()

        try store.uncomplete(itemID: completedItem.id)

        let activeItems = try store.fetchItems().filter { !$0.isCompleted }
            .sorted { $0.sortOrder < $1.sortOrder }
        #expect(activeItems.count == 2)
        #expect(activeItems[0].id == activeItem.id)
        #expect(activeItems[1].id == completedItem.id)
        #expect(activeItems[1].sortOrder > activeItems[0].sortOrder)
    }

    @Test("Merge policy prefers store when store updatedAt is newer")
    func mergePolicyPrefersStoreWhenStoreIsNewer() async throws {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.viewContext
        viewContext.automaticallyMergesChangesFromParent = false

        let item = ItemEntity(context: viewContext)
        item.title = "Original"
        item.updatedAt = Date(timeIntervalSince1970: 100)
        try viewContext.save()

        let itemID = item.id

        let backgroundContext = controller.container.newBackgroundContext()
        try await backgroundContext.perform {
            let request = ItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
            request.fetchLimit = 1

            guard let remote = try backgroundContext.fetch(request).first else {
                Issue.record("Expected item to exist in background context")
                return
            }

            remote.title = "Remote newer"
            remote.updatedAt = Date(timeIntervalSince1970: 200)
            try backgroundContext.save()
        }

        item.updatedAt = Date(timeIntervalSince1970: 150)
        try viewContext.save()

        let verifyContext = controller.container.newBackgroundContext()
        try await verifyContext.perform {
            let request = ItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
            request.fetchLimit = 1

            guard let resolved = try verifyContext.fetch(request).first else {
                Issue.record("Expected item to exist in verify context")
                return
            }

            #expect(resolved.title == "Remote newer")
            #expect(resolved.updatedAt == Date(timeIntervalSince1970: 200))
        }
    }

    @Test("Merge policy prefers local when local updatedAt is newer")
    func mergePolicyPrefersLocalWhenLocalIsNewer() async throws {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.viewContext
        viewContext.automaticallyMergesChangesFromParent = false

        let item = ItemEntity(context: viewContext)
        item.title = "Original"
        item.updatedAt = Date(timeIntervalSince1970: 100)
        try viewContext.save()

        let itemID = item.id

        let backgroundContext = controller.container.newBackgroundContext()
        try await backgroundContext.perform {
            let request = ItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
            request.fetchLimit = 1

            guard let remote = try backgroundContext.fetch(request).first else {
                Issue.record("Expected item to exist in background context")
                return
            }

            remote.title = "Remote older"
            remote.updatedAt = Date(timeIntervalSince1970: 200)
            try backgroundContext.save()
        }

        item.updatedAt = Date(timeIntervalSince1970: 300)
        try viewContext.save()

        let verifyContext = controller.container.newBackgroundContext()
        try await verifyContext.perform {
            let request = ItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
            request.fetchLimit = 1

            guard let resolved = try verifyContext.fetch(request).first else {
                Issue.record("Expected item to exist in verify context")
                return
            }

            #expect(resolved.title == "Original")
            #expect(resolved.updatedAt == Date(timeIntervalSince1970: 300))
        }
    }
}
