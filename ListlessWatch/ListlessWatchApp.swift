import SwiftUI

@main
struct ListlessWatchApp: App {
    private let persistenceController = PersistenceController.shared
    private let keyValueSyncBridge = KeyValueSyncBridge(keys: ["listName", "colorTheme"])

    init() {
        keyValueSyncBridge.start()
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
