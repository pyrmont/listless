import SwiftUI

@main
struct ListlessiOSApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = 0
    private let persistenceController: PersistenceController

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
        persistenceController = isUITesting ? PersistenceController(inMemory: true) : .shared
    }

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
                .onChange(of: appearanceMode, initial: true) { _, newValue in
                    let style: UIUserInterfaceStyle = switch newValue {
                    case 1: .light
                    case 2: .dark
                    default: .unspecified
                    }
                    for scene in UIApplication.shared.connectedScenes {
                        guard let windowScene = scene as? UIWindowScene else { continue }
                        for window in windowScene.windows {
                            window.overrideUserInterfaceStyle = style
                        }
                    }
                }
                .overlay(alignment: .top) {
                    Color.outerBackground
                        .opacity(0.9)
                        .ignoresSafeArea(edges: .top)
                        .frame(height: 0)
                }
        }
        .commands {
            TaskCommands()
        }
    }
}
