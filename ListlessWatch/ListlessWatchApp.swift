import SwiftUI

@main
struct ListlessWatchApp: App {
    private let persistenceController = PersistenceController.shared
    private let keyValueSyncBridge = KeyValueSyncBridge(keys: ["headingText"])

    init() {
        keyValueSyncBridge.start()
    }

    var body: some Scene {
        WindowGroup {
            TaskListView(
                store: TaskStore(persistenceController: persistenceController),
                syncMonitor: persistenceController.syncMonitor
            )
            .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}
