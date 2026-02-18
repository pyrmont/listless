import SwiftUI

@main
struct ListlessiOSApp: App {
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            TaskListView(
                store: TaskStore(persistenceController: persistenceController),
                syncMonitor: persistenceController.syncMonitor
            )
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 8)
                }
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .overlay(alignment: .top) {
                    Color.outerBackground
                        .opacity(0.9)
                        .ignoresSafeArea(edges: .top)
                        .frame(height: 0)
                }
        }
    }
}
