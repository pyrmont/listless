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
                let item = conflict.sourceObject as? ItemEntity,
                let objectSnapshot = conflict.objectSnapshot,
                let persistedSnapshot = conflict.persistedSnapshot,
                let storeUpdatedAt = persistedSnapshot["updatedAt"] as? Date
            else {
                fallbackConflicts.append(item)
                continue
            }

            let localUpdatedAt = (objectSnapshot["updatedAt"] as? Date) ?? item.updatedAt

            // Keep local in-memory values if they are newer or equal.
            guard storeUpdatedAt > localUpdatedAt else { continue }

            // Persisted values are newer; copy them onto the object to resolve conflict.
            // Use setPrimitiveValue to bypass KVC change tracking so willSave() does not
            // see these keys in changedValues() and overwrite updatedAt with Date().
            for (key, value) in persistedSnapshot {
                if value is NSNull {
                    item.setPrimitiveValue(nil, forKey: key)
                } else {
                    item.setPrimitiveValue(value, forKey: key)
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

    let container: NSPersistentContainer
    let syncMonitor: CloudKitSyncMonitor

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        syncMonitor = CloudKitSyncMonitor()

        if inMemory {
            // Use a plain NSPersistentContainer (no CloudKit) with a unique
            // temporary store so each launch is fully isolated.
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("sqlite")
            container = NSPersistentContainer(name: "Listless")
            container.persistentStoreDescriptions.first?.url = tempURL
        } else {
            container = NSPersistentCloudKitContainer(name: "Listless")
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

        if !inMemory, let cloudContainer = container as? NSPersistentCloudKitContainer {
            syncMonitor.startMonitoring(container: cloudContainer)
        }

    }

    func save() throws {
        let context = container.viewContext

        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            throw ItemStoreError.saveFailed(error)
        }
    }
}
