import Foundation
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

@Suite("ItemStore Delete Multiple & Normalize", .serialized)
@MainActor
struct ItemStoreDeleteAndNormalizeTests {

    // MARK: - deleteMultiple

    @Test("Delete multiple items removes all specified items")
    func deleteMultipleBasic() async throws {
        let (store, ids) = try makeTestStoreWithItems(count: 4)

        try store.deleteMultiple(itemIDs: [ids[0], ids[2]])

        let remaining = try store.fetchItems()
        let remainingIDs = remaining.map(\.id)
        #expect(remainingIDs.contains(ids[1]))
        #expect(remainingIDs.contains(ids[3]))
        #expect(!remainingIDs.contains(ids[0]))
        #expect(!remainingIDs.contains(ids[2]))
        #expect(remaining.count == 2)
    }

    @Test("Delete multiple with empty array does nothing")
    func deleteMultipleEmpty() async throws {
        let (store, _) = try makeTestStoreWithItems(count: 3)

        try store.deleteMultiple(itemIDs: [])

        let items = try store.fetchItems()
        #expect(items.count == 3)
    }

    @Test("Delete multiple skips unknown IDs without error")
    func deleteMultipleWithUnknownIDs() async throws {
        let (store, ids) = try makeTestStoreWithItems(count: 3)

        try store.deleteMultiple(itemIDs: [ids[0], UUID(), ids[2]])

        let remaining = try store.fetchItems()
        #expect(remaining.count == 1)
        #expect(remaining[0].id == ids[1])
    }

    @Test("Delete multiple handles mix of active and completed items")
    func deleteMultipleMixedState() async throws {
        let (store, ids) = try makeTestStoreWithItems(count: 4)
        try store.complete(itemID: ids[1])
        try store.complete(itemID: ids[3])

        try store.deleteMultiple(itemIDs: [ids[0], ids[1]])

        let remaining = try store.fetchItems()
        let remainingIDs = Set(remaining.map(\.id))
        #expect(remainingIDs == Set([ids[2], ids[3]]))
    }

    @Test("Delete multiple with all items leaves store empty")
    func deleteMultipleAll() async throws {
        let (store, ids) = try makeTestStoreWithItems(count: 3)

        try store.deleteMultiple(itemIDs: ids)

        let items = try store.fetchItems()
        #expect(items.isEmpty)
    }

    // MARK: - normalizeSortOrders

    @Test("Normalize assigns evenly spaced sort orders")
    func normalizeBasic() async throws {
        let (store, ids) = try makeTestStoreWithItems(count: 3)
        // Move items around to create irregular spacing.
        try store.moveItem(itemID: ids[2], toIndex: 0)

        try store.normalizeSortOrders()

        let items = try store.fetchItems().filter { !$0.isCompleted }
        #expect(items.count == 3)
        for (index, item) in items.enumerated() {
            #expect(item.sortOrder == Int64(index) * 1000)
        }
    }

    @Test("Normalize preserves existing order")
    func normalizePreservesOrder() async throws {
        let (store, _) = try makeTestStoreWithItems(
            count: 3, titles: ["First", "Second", "Third"])

        try store.normalizeSortOrders()

        let items = try store.fetchItems().filter { !$0.isCompleted }
        #expect(items.map(\.title) == ["First", "Second", "Third"])
    }

    @Test("Normalize on empty store does nothing")
    func normalizeEmpty() async throws {
        let store = makeTestStore()

        try store.normalizeSortOrders()

        let items = try store.fetchItems()
        #expect(items.isEmpty)
    }

    @Test("Normalize ignores completed items")
    func normalizeIgnoresCompleted() async throws {
        let (store, ids) = try makeTestStoreWithItems(count: 4)
        try store.complete(itemID: ids[1])
        try store.complete(itemID: ids[3])

        try store.normalizeSortOrders()

        let active = try store.fetchItems().filter { !$0.isCompleted }
        #expect(active.count == 2)
        #expect(active[0].sortOrder == 0)
        #expect(active[1].sortOrder == 1000)

        // Completed items should still exist.
        let all = try store.fetchItems()
        #expect(all.count == 4)
    }

    @Test("Normalize then create at beginning uses correct offset")
    func normalizeFollowedByPrepend() async throws {
        let (store, _) = try makeTestStoreWithItems(count: 3)
        try store.normalizeSortOrders()

        // After normalize: sort orders are 0, 1000, 2000.
        // Creating at beginning should use minSortOrder - 1000 = -1000.
        _ = try store.createItem(title: "Prepended", atBeginning: true)
        try store.save()

        let items = try store.fetchItems().filter { !$0.isCompleted }
        #expect(items.first?.title == "Prepended")
        #expect(items.first?.sortOrder == -1000)
    }

    @Test("Normalize with single item sets sort order to zero")
    func normalizeSingleItem() async throws {
        let store = makeTestStore()
        _ = try store.createItem(title: "Only", atBeginning: true)
        try store.save()

        try store.normalizeSortOrders()

        let items = try store.fetchItems().filter { !$0.isCompleted }
        #expect(items.count == 1)
        #expect(items[0].sortOrder == 0)
    }

    @Test("Double normalize is idempotent")
    func doubleNormalize() async throws {
        let (store, _) = try makeTestStoreWithItems(count: 4)
        try store.moveItem(itemID: try store.fetchItems()[3].id, toIndex: 0)

        try store.normalizeSortOrders()
        let afterFirst = try store.fetchItems().filter { !$0.isCompleted }.map(\.sortOrder)

        try store.normalizeSortOrders()
        let afterSecond = try store.fetchItems().filter { !$0.isCompleted }.map(\.sortOrder)

        #expect(afterFirst == afterSecond)
    }

    @Test("Normalize fixes negative sort orders from prepend operations")
    func normalizeFixesNegativeOrders() async throws {
        let store = makeTestStore()
        _ = try store.createItem(title: "Original")
        try store.save()
        _ = try store.createItem(title: "Prepended", atBeginning: true)
        try store.save()

        let beforeNormalize = try store.fetchItems().filter { !$0.isCompleted }
        #expect(beforeNormalize[0].sortOrder < 0)

        try store.normalizeSortOrders()

        let afterNormalize = try store.fetchItems().filter { !$0.isCompleted }
        #expect(afterNormalize[0].sortOrder == 0)
        #expect(afterNormalize[1].sortOrder == 1000)
        #expect(afterNormalize[0].title == "Prepended")
    }
}
