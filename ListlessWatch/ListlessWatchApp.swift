import SwiftUI

@main
struct ListlessWatchApp: App {
    private let persistenceController: PersistenceController
    private let keyValueSyncBridge = KeyValueSyncBridge(keys: ["listName", "colorTheme"])

    init() {
        let args = ProcessInfo.processInfo.arguments
        let isUITesting = args.contains("UI_TESTING")
        persistenceController = isUITesting ? PersistenceController(inMemory: true) : .shared
        keyValueSyncBridge.start()

        if isUITesting, args.contains("SCREENSHOT_SEED") {
            let store = ItemStore(persistenceController: persistenceController)
            try? store.createItem(title: "Make smartband", sortOrder: 1000)
            try? store.createItem(title: "Add custom faces", sortOrder: 2000)
            let item = try? store.createItem(title: "Focus on fitness", sortOrder: 3000)
            if let item { try? store.complete(itemID: item.id) }
            try? store.save()
        }
    }

    var body: some Scene {
        WindowGroup {
            ItemListView(
                store: ItemStore(persistenceController: persistenceController),
                syncMonitor: persistenceController.syncMonitor
            )
            .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}
