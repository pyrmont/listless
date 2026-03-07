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
            // Use setPrimitiveValue to bypass KVC change tracking so willSave() does not
            // see these keys in changedValues() and overwrite updatedAt with Date().
            for (key, value) in persistedSnapshot {
                if value is NSNull {
                    task.setPrimitiveValue(nil, forKey: key)
                } else {
                    task.setPrimitiveValue(value, forKey: key)
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
    let syncMonitor: CloudKitSyncMonitor

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Listless")
        syncMonitor = CloudKitSyncMonitor()

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure CloudKit sync
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve persistent store description")
            }

#if DEBUG
            if let storeURL = description.url {
                // Keep debug builds isolated from TestFlight/App Store local Core Data files.
                description.url = storeURL.deletingLastPathComponent().appendingPathComponent(
                    "Listless-Debug.sqlite"
                )
            }
#endif

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

        if !inMemory {
            syncMonitor.startMonitoring(container: container)
        }

    }

    func save() throws {
        let context = container.viewContext

        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            throw TaskStoreError.saveFailed(error)
        }
    }
}
