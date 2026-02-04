import SwiftUI

@main
struct ListlessMacApp: App {
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            TaskListView(store: TaskStore(persistenceController: persistenceController))
        }
    }
}
