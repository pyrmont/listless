import Foundation
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

/// Creates a fresh ItemStore with in-memory persistence for isolated testing.
@MainActor
func makeTestStore() -> ItemStore {
    let controller = PersistenceController(inMemory: true)
    return ItemStore(persistenceController: controller)
}

/// Creates a ItemStore pre-populated with test items.
/// - Parameters:
///   - count: Number of items to create (default: 3)
///   - titles: Optional array of titles; if nil, generates "Item 1", "Item 2", etc.
/// - Returns: Tuple of (store, array of created item IDs)
@MainActor
func makeTestStoreWithItems(count: Int = 3, titles: [String]? = nil) throws -> (ItemStore, [UUID]) {
    let store = makeTestStore()
    var itemIDs: [UUID] = []

    for i in 0..<count {
        let title = titles?[safe: i] ?? "Task \(i + 1)"
        let item = try store.createItem(title: title)
        try store.save()
        itemIDs.append(item.id)
    }

    return (store, itemIDs)
}

/// Safe array subscript that returns nil instead of crashing on out-of-bounds access.
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
