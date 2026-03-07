import SwiftUI

@main
struct ListlessWatchApp: App {
    private let persistenceController = PersistenceController.shared

    init() {
        let kvStore = NSUbiquitousKeyValueStore.default
        kvStore.synchronize()
        if let heading = kvStore.string(forKey: "headingText") {
            UserDefaults.standard.set(heading, forKey: "headingText")
        }
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
