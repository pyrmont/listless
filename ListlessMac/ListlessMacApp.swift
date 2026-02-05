import SwiftUI

@main
struct ListlessMacApp: App {
    private let persistenceController: PersistenceController

    init() {
        // Use in-memory storage during UI tests
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
        persistenceController = isUITesting ? PersistenceController(inMemory: true) : .shared
    }

    var body: some Scene {
        WindowGroup {
            TaskListView(store: TaskStore(persistenceController: persistenceController))
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}
