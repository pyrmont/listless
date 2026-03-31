import CoreData
import Foundation

enum ItemStoreError: LocalizedError {
    case fetchFailed(Error)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to fetch items: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save changes: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class ItemStore {
    private let persistenceController: PersistenceController
    private var context: NSManagedObjectContext {
        persistenceController.viewContext
    }

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    func fetchItems() throws -> [ItemEntity] {
        do {
            let activeRequest = ItemEntity.fetchRequest()
            activeRequest.predicate = NSPredicate(format: "completedOrder == 0")
            activeRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ItemEntity.sortOrder, ascending: true)
            ]

            let completedRequest = ItemEntity.fetchRequest()
            completedRequest.predicate = NSPredicate(format: "completedOrder > 0")
            completedRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ItemEntity.completedOrder, ascending: false)
            ]

            let activeItems = try context.fetch(activeRequest)
            let completedItems = try context.fetch(completedRequest)

            return activeItems + completedItems
        } catch {
            throw ItemStoreError.fetchFailed(error)
        }
    }

    @discardableResult
    func createItem(title: String = "", atBeginning: Bool = false, sortOrder: Int64? = nil) throws
        -> ItemEntity
    {
        // Compute sort order before inserting the new object so we don't need
        // processPendingChanges() and the new item can't appear in our own query.
        let resolvedSortOrder: Int64
        if let sortOrder {
            resolvedSortOrder = sortOrder
        } else if atBeginning {
            let minOrder = try minActiveSortOrder() ?? 0
            resolvedSortOrder = minOrder - 1000
        } else {
            let maxOrder = try maxActiveSortOrder() ?? -1000
            resolvedSortOrder = maxOrder + 1000
        }

        let item = ItemEntity(context: context)
        item.title = title
        item.sortOrder = resolvedSortOrder

        return item
    }

    private func minActiveSortOrder() throws -> Int64? {
        let request = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "completedOrder == 0")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ItemEntity.sortOrder, ascending: true)
        ]
        request.fetchLimit = 1
        do {
            return try context.fetch(request).first?.sortOrder
        } catch {
            throw ItemStoreError.fetchFailed(error)
        }
    }

    private func maxActiveSortOrder() throws -> Int64? {
        let request = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "completedOrder == 0")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ItemEntity.sortOrder, ascending: false)
        ]
        request.fetchLimit = 1
        do {
            return try context.fetch(request).first?.sortOrder
        } catch {
            throw ItemStoreError.fetchFailed(error)
        }
    }

    func complete(itemID: UUID) throws {
        guard let item = try findItem(id: itemID) else { return }

        let request = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "completedOrder > 0")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ItemEntity.completedOrder, ascending: false)
        ]
        request.fetchLimit = 1
        let maxOrder = (try context.fetch(request).first)?.completedOrder ?? 0

        item.completedOrder = maxOrder + 1
        try save()
    }

    func uncomplete(itemID: UUID) throws {
        guard let item = try findItem(id: itemID) else { return }
        let restoredSortOrder = item.sortOrder
        let activeItems = try fetchItems().filter { !$0.isCompleted && $0.id != item.id }
        let hasSortOrderConflict = activeItems.contains { $0.sortOrder == restoredSortOrder }

        if hasSortOrderConflict {
            let maxSortOrder = activeItems.map(\.sortOrder).max() ?? -1000
            item.sortOrder = maxSortOrder + 1000
        }

        item.completedOrder = 0
        try save()
    }

    func update(itemID: UUID, title: String) throws {
        guard let item = try findItem(id: itemID) else { return }
        item.title = title
        try save()
    }

    func updateWithoutSaving(itemID: UUID, title: String) throws {
        guard let item = try findItem(id: itemID) else { return }
        item.title = title
        // Don't save - will be saved when editing ends
    }

    func delete(itemID: UUID) throws {
        guard let item = try findItem(id: itemID) else { return }
        context.delete(item)
        try save()
    }

    func deleteMultiple(itemIDs: [UUID]) throws {
        for itemID in itemIDs {
            guard let item = try findItem(id: itemID) else { continue }
            context.delete(item)
        }
        try save()
    }

    func normalizeSortOrders() throws {
        let activeItems = try fetchItems().filter { !$0.isCompleted }
            .sorted { $0.sortOrder < $1.sortOrder }

        for (index, item) in activeItems.enumerated() {
            item.sortOrder = Int64(index) * 1000
        }

        try save()
    }

    func moveItem(itemID: UUID, toIndex: Int) throws {
        let activeItems = try fetchItems().filter { !$0.isCompleted }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let currentIndex = activeItems.firstIndex(where: { $0.id == itemID }) else { return }
        guard currentIndex != toIndex else { return }

        var reordered = activeItems
        let item = reordered.remove(at: currentIndex)

        // Clamp toIndex to valid range [0, reordered.count] after removal
        let insertIndex = max(0, min(toIndex, reordered.count))
        reordered.insert(item, at: insertIndex)

        // Reassign sortOrder with gaps of 1000
        for (index, item) in reordered.enumerated() {
            item.sortOrder = Int64(index) * 1000
        }

        try save()
    }

    private func findItem(id: UUID) throws -> ItemEntity? {
        let request = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            throw ItemStoreError.fetchFailed(error)
        }
    }

    func save() throws {
        try persistenceController.save()
    }
}
