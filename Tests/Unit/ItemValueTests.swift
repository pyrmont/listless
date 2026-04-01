import Foundation
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

@Suite("ItemValue Snapshot", .serialized)
@MainActor
struct ItemValueTests {

    @Test("ItemValue copies all fields from active ItemEntity")
    func snapshotActiveItem() async throws {
        let store = makeTestStore()
        let entity = try store.createItem(title: "Buy milk")
        try store.save()

        let value = ItemValue(entity)

        #expect(value.id == entity.id)
        #expect(value.title == entity.title)
        #expect(value.isCompleted == false)
        #expect(value.sortOrder == entity.sortOrder)
        #expect(value.completedOrder == 0)
    }

    @Test("ItemValue copies completed state correctly")
    func snapshotCompletedItem() async throws {
        let store = makeTestStore()
        let entity = try store.createItem(title: "Done task")
        try store.save()
        try store.complete(itemID: entity.id)

        let items = try store.fetchItems()
        let completed = items.first { $0.id == entity.id }!
        let value = ItemValue(completed)

        #expect(value.isCompleted == true)
        #expect(value.completedOrder > 0)
        #expect(value.completedOrder == completed.completedOrder)
    }

    @Test("ItemValue is independent of entity mutations")
    func snapshotIndependence() async throws {
        let store = makeTestStore()
        let entity = try store.createItem(title: "Original")
        try store.save()

        let value = ItemValue(entity)
        try store.update(itemID: entity.id, title: "Changed")

        #expect(value.title == "Original")
        #expect(entity.title == "Changed")
    }

    @Test("ItemValue preserves sort order from entity")
    func snapshotSortOrder() async throws {
        let (store, ids) = try makeTestStoreWithItems(count: 3)
        let items = try store.fetchItems()

        let values = items.filter { !$0.isCompleted }.map { ItemValue($0) }

        #expect(values.count == 3)
        for (i, value) in values.enumerated() {
            #expect(value.id == ids[i])
        }
        #expect(values[0].sortOrder < values[1].sortOrder)
        #expect(values[1].sortOrder < values[2].sortOrder)
    }
}
