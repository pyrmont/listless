import SwiftUI

// MARK: - App Delegate

class IOSAppDelegate: UIResponder, UIApplicationDelegate {
    override func buildMenu(with builder: UIMenuBuilder) {
        guard builder.system == .main else {
            super.buildMenu(with: builder)
            return
        }

        // File menu — New Item (⌘N)
        let newItem = UIKeyCommand(
            title: "New Item",
            action: IOSMenuSelectors.newItem,
            input: "n",
            modifierFlags: .command
        )
        builder.insertChild(
            UIMenu(title: "", options: .displayInline, children: [newItem]),
            atStartOfMenu: .file
        )

        // Edit menu — Move Up (⌘↑), Move Down (⌘↓), Delete (⌘⌫),
        //              Mark as Complete (⌘Space)
        let moveUp = UIKeyCommand(
            title: "Move Up",
            action: IOSMenuSelectors.moveUp,
            input: UIKeyCommand.inputUpArrow,
            modifierFlags: .command
        )
        let moveDown = UIKeyCommand(
            title: "Move Down",
            action: IOSMenuSelectors.moveDown,
            input: UIKeyCommand.inputDownArrow,
            modifierFlags: .command
        )
        let delete = UIKeyCommand(
            title: "Delete",
            action: IOSMenuSelectors.deleteItem,
            input: "\u{8}",
            modifierFlags: .command
        )
        let markComplete = UIKeyCommand(
            title: "Mark as Complete",
            action: IOSMenuSelectors.markCompleted,
            input: " ",
            modifierFlags: .command
        )
        builder.insertChild(
            UIMenu(title: "", options: .displayInline, children: [
                moveUp, moveDown, delete, markComplete,
            ]),
            atEndOfMenu: .edit
        )
    }
}

// MARK: - App

@main
struct ListlessiOSApp: App {
    @UIApplicationDelegateAdaptor(IOSAppDelegate.self) var appDelegate
    @AppStorage("appearanceMode") private var appearanceMode = 0
    @AppStorage("didCompleteTutorial") private var didCompleteTutorial = false
    private let persistenceController: PersistenceController
    private let keyValueSyncBridge = KeyValueSyncBridge(keys: ["listName", "colorTheme"])

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
        persistenceController = isUITesting ? PersistenceController(inMemory: true) : .shared
        keyValueSyncBridge.start()

        if isUITesting {
            UserDefaults.standard.set(true, forKey: "didCompleteTutorial")
        }
    }

    var body: some Scene {
        WindowGroup {
            if didCompleteTutorial {
                mainListView
            } else {
                tutorialListView
            }
        }
    }

    private var mainListView: some View {
        ItemListView(
            store: ItemStore(persistenceController: persistenceController),
            syncMonitor: persistenceController.syncMonitor
        )
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 8)
        }
        .environment(\.managedObjectContext, persistenceController.viewContext)
        .onChange(of: appearanceMode, initial: true) { _, newValue in
            applyAppearanceMode(newValue)
        }
        .overlay(alignment: .top) {
            Color.outerBackground
                .opacity(0.9)
                .ignoresSafeArea(edges: .top)
                .frame(height: 0)
        }
    }

    private var tutorialListView: some View {
        let pc = PersistenceController(inMemory: true)
        let store = ItemStore(persistenceController: pc)
        TutorialSeeder.seed(store: store)
        return ItemListView(
            store: store,
            syncMonitor: pc.syncMonitor,
            onFinishTutorial: { didCompleteTutorial = true }
        )
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 8)
        }
        .environment(\.managedObjectContext, pc.viewContext)
        .onChange(of: appearanceMode, initial: true) { _, newValue in
            applyAppearanceMode(newValue)
        }
        .overlay(alignment: .top) {
            Color.outerBackground
                .opacity(0.9)
                .ignoresSafeArea(edges: .top)
                .frame(height: 0)
        }
    }

    private func applyAppearanceMode(_ mode: Int) {
        let style: UIUserInterfaceStyle = switch mode {
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
}
