import SwiftUI

// MARK: - App Delegate

class IOSAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.newData)
    }

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

        // Edit menu — Page Up (⌥↑), Page Down (⌥↓),
        //              Jump to Top (⌘⌥↑), Jump to Bottom (⌘⌥↓).
        // Provides Magic Keyboard users an alternative to the absent
        // Page/Home/End keys.
        let pageUp = UIKeyCommand(
            title: "Page Up",
            action: IOSMenuSelectors.navigatePageUp,
            input: UIKeyCommand.inputUpArrow,
            modifierFlags: .alternate
        )
        let pageDown = UIKeyCommand(
            title: "Page Down",
            action: IOSMenuSelectors.navigatePageDown,
            input: UIKeyCommand.inputDownArrow,
            modifierFlags: .alternate
        )
        let jumpToTop = UIKeyCommand(
            title: "Jump to Top",
            action: IOSMenuSelectors.navigateToFirst,
            input: UIKeyCommand.inputUpArrow,
            modifierFlags: [.command, .alternate]
        )
        let jumpToBottom = UIKeyCommand(
            title: "Jump to Bottom",
            action: IOSMenuSelectors.navigateToLast,
            input: UIKeyCommand.inputDownArrow,
            modifierFlags: [.command, .alternate]
        )
        builder.insertChild(
            UIMenu(title: "", options: .displayInline, children: [
                pageUp, pageDown, jumpToTop, jumpToBottom,
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
        PerfSampler.markLaunchStart()
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
        persistenceController = isUITesting ? PersistenceController(inMemory: true) : .shared
        keyValueSyncBridge.start()

        if isUITesting {
            UserDefaults.standard.set(true, forKey: "didCompleteTutorial")
            let theme = ProcessInfo.processInfo.arguments.contains("THEME_COLLAROY") ? 1 : 0
            UserDefaults.standard.set(theme, forKey: "colorTheme")
        }
    }

    var body: some Scene {
        WindowGroup {
            if didCompleteTutorial {
                mainListView
            } else {
                TutorialListView { didCompleteTutorial = true }
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

// MARK: - Tutorial

struct TutorialListView: View {
    @AppStorage("appearanceMode") private var appearanceMode = 0
    @State private var persistenceController = PersistenceController(inMemory: true)
    var onFinishTutorial: () -> Void

    var body: some View {
        let store = ItemStore(persistenceController: persistenceController)
        TutorialSeeder.seed(store: store)
        return ItemListView(
            store: store,
            syncMonitor: persistenceController.syncMonitor,
            onFinishTutorial: onFinishTutorial
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
