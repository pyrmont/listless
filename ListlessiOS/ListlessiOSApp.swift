import SwiftUI

@main
struct ListlessiOSApp: App {
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                TaskListView(store: TaskStore(persistenceController: persistenceController))
                    .navigationTitle("Tasks")
                    .navigationBarTitleDisplayMode(.large)
                    .safeAreaInset(edge: .top) {
                        Color.clear.frame(height: 8)
                    }
                    .environment(\.managedObjectContext, persistenceController.viewContext)
            }
        }
    }
}
