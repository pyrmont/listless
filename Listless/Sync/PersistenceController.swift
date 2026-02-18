import CoreData
import Foundation

private final class UpdatedAtMergePolicy: NSMergePolicy {
    private let fallbackPolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)

    init() {
        super.init(merge: .mergeByPropertyStoreTrumpMergePolicyType)
    }

    override func resolve(mergeConflicts list: [Any]) throws {
        var fallbackConflicts: [Any] = []

        for item in list {
            guard
                let conflict = item as? NSMergeConflict,
                let task = conflict.sourceObject as? TaskItem,
                let objectSnapshot = conflict.objectSnapshot,
                let persistedSnapshot = conflict.persistedSnapshot,
                let storeUpdatedAt = persistedSnapshot["updatedAt"] as? Date
            else {
                fallbackConflicts.append(item)
                continue
            }

            let localUpdatedAt = (objectSnapshot["updatedAt"] as? Date) ?? task.updatedAt

            // Keep local in-memory values if they are newer or equal.
            guard storeUpdatedAt > localUpdatedAt else { continue }

            // Persisted values are newer; copy them onto the object to resolve conflict.
            for (key, value) in persistedSnapshot {
                if value is NSNull {
                    task.setValue(nil, forKey: key)
                } else {
                    task.setValue(value, forKey: key)
                }
            }
        }

        if !fallbackConflicts.isEmpty {
            try fallbackPolicy.resolve(mergeConflicts: fallbackConflicts)
        }
    }
}

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Listless")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure CloudKit sync
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve persistent store description")
            }

            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.net.inqk.listless"
            )

            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(
                true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = UpdatedAtMergePolicy()

        performDataMigrationIfNeeded()
    }

    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }

    private func performDataMigrationIfNeeded() {
        let hasRun = UserDefaults.standard.bool(forKey: "didMigrateSortOrder_v1")
        guard !hasRun else { return }

        let context = container.viewContext
        let request = TaskItem.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true),
        ]

        guard let tasks = try? context.fetch(request) else { return }

        let activeTasks = tasks.filter { !$0.isCompleted }

        // Only set sortOrder for active tasks
        for (index, task) in activeTasks.enumerated() {
            task.sortOrder = Int64(index) * 1000
        }

        // Completed tasks: sortOrder can be 0 (not used)
        // They'll be sorted by updatedAt instead

        try? context.save()
        UserDefaults.standard.set(true, forKey: "didMigrateSortOrder_v1")
    }
}
