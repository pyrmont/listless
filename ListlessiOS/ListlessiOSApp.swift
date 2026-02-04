import SwiftUI

@main
struct ListlessiOSApp: App {
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            TaskListView(store: TaskStore(persistenceController: persistenceController))
        }
    }
}
