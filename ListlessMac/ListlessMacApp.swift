import SwiftUI
import AppKit

private let customMenuTag = 1001

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    func applicationDidFinishLaunching(_ notification: Notification) {
        removeFormatMenu()

        // SwiftUI builds menus asynchronously; watch for items appearing.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuDidAddItem(_:)),
            name: NSMenu.didAddItemNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

        // SwiftUI/AppKit can finish menu construction after launch callbacks; apply
        // our menu patch repeatedly in the first moments to avoid startup races.
        refreshMenus()
        let startupDelays: [TimeInterval] = [0.0, 0.05, 0.15, 0.35]
        for delay in startupDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refreshMenus()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleMenuDidAddItem(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.removeFormatMenu()
            self?.setupFileMenuIfNeeded()
            self?.setupEditMenuIfNeeded()
        }
    }

    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        refreshMenus()
    }

    @objc private func handleWindowDidBecomeKey(_ notification: Notification) {
        refreshMenus()
    }

    private func refreshMenus() {
        removeFormatMenu()
        setupFileMenuIfNeeded()
        setupEditMenuIfNeeded()
    }

    // MARK: - Menu Setup

    @MainActor private func removeFormatMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }
        mainMenu.items
            .filter { $0.title == "Format" }
            .forEach { mainMenu.removeItem($0) }
    }

    @MainActor private func setupFileMenuIfNeeded() {
        guard let fileMenu = NSApp.mainMenu?.items.first(where: { $0.title == "File" })?.submenu else { return }

        // Always update the New Window shortcut in-place — runs on every notification
        // in case SwiftUI re-adds a fresh item. Never remove it; removal causes SwiftUI
        // to re-add it at the bottom with the original shortcut.
        if let newWindowItem = fileMenu.items.first(where: { $0.action == NSSelectorFromString("menuAction:") }) {
            newWindowItem.keyEquivalent = "n"
            newWindowItem.keyEquivalentModifierMask = [.command, .shift]
        }

        guard !fileMenu.items.contains(where: { $0.tag == customMenuTag }) else { return }

        // Defer until both Close and Close All are present — the build order of these
        // items is non-deterministic, so we wait for both before touching anything.
        guard fileMenu.items.contains(where: { $0.action == NSSelectorFromString("performClose:") }),
              fileMenu.items.contains(where: { $0.action == NSSelectorFromString("closeAll:") }) else { return }

        guard let newWindowItem = fileMenu.items.first(where: { $0.action == NSSelectorFromString("menuAction:") }) else { return }
        let insertIndex = fileMenu.index(of: newWindowItem)

        // Insert sep1 and New Task before New Window, then sep2 immediately after it.
        // We own both separators so the layout is stable regardless of where the
        // system separator between Close/Close All ends up.
        let sep1 = NSMenuItem.separator()
        sep1.tag = customMenuTag
        fileMenu.insertItem(sep1, at: insertIndex)

        let newTaskItem = NSMenuItem(title: "New Task", action: #selector(handleNewTask), keyEquivalent: "n")
        newTaskItem.keyEquivalentModifierMask = .command
        newTaskItem.target = self
        newTaskItem.tag = customMenuTag
        fileMenu.insertItem(newTaskItem, at: insertIndex)

        // New Window is now at insertIndex + 2; place sep2 immediately after it.
        let sep2 = NSMenuItem.separator()
        sep2.tag = customMenuTag
        fileMenu.insertItem(sep2, at: insertIndex + 3)
    }

    @MainActor private func setupEditMenuIfNeeded() {
        guard let editMenu = NSApp.mainMenu?.items.first(where: { $0.title == "Edit" })?.submenu else { return }

        // NOTE: Any new menu key equivalents added in this file should also be mapped in
        // TaskListView.keyboardNavigation(...). SwiftUI's onKeyPress layer can intercept
        // events before AppKit key equivalents, so duplicating shortcut bindings at the
        // SwiftUI layer keeps shortcut handling reliable.

        // Modify the system "Delete" item in-place so it stays in its expected position
        // but dispatches our action with our preferred shortcut (⌫). Runs on every
        // notification in case SwiftUI re-adds a fresh item; left untagged so the guard
        // below can still fire correctly on first setup.
        if let systemDelete = editMenu.items.first(where: { $0.action == NSSelectorFromString("delete:") }) {
            systemDelete.action = #selector(handleDeleteTask)
            systemDelete.target = self
            systemDelete.keyEquivalent = "\u{08}"
            systemDelete.keyEquivalentModifierMask = []
        }

        guard !editMenu.items.contains(where: { $0.tag == customMenuTag }) else { return }

        func addSep() {
            let s = NSMenuItem.separator()
            s.tag = customMenuTag
            editMenu.addItem(s)
        }

        func addItem(title: String, action: Selector, key: String, modifiers: NSEvent.ModifierFlags) {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = modifiers
            i.target = self
            i.tag = customMenuTag
            editMenu.addItem(i)
        }

        addSep()
        addItem(title: "Move Up",           action: #selector(handleMoveUp),         key: "\u{F700}", modifiers: .command)
        addItem(title: "Move Down",         action: #selector(handleMoveDown),        key: "\u{F701}", modifiers: .command)
        addItem(title: "Mark as Completed", action: #selector(handleMarkCompleted),   key: " ",        modifiers: [])
        addSep()
        addItem(title: "Clear Completed",   action: #selector(handleClearCompleted),  key: "",         modifiers: [])
    }

    // MARK: - NSMenuItemValidation
    // AppKit calls this automatically for each item targeting self, both when the
    // menu opens and when keyboard shortcuts are evaluated.

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let coord = MenuCoordinator.shared
        switch menuItem.action {
        case #selector(handleDeleteTask):     return coord.canDeleteSelectedTask
        case #selector(handleMoveUp):         return coord.canMoveSelectedTaskUp
        case #selector(handleMoveDown):       return coord.canMoveSelectedTaskDown
        case #selector(handleMarkCompleted):
            menuItem.title = coord.markCompletedTitle
            return coord.canMarkSelectedTaskCompleted
        case #selector(handleClearCompleted): return coord.canClearCompletedTasks
        default: return true
        }
    }

    // MARK: - Actions

    @objc private func handleNewTask() {
        MenuCoordinator.shared.newTask?()
    }

    @objc private func handleDeleteTask() {
        MenuCoordinator.shared.deleteSelectedTask?()
    }

    @objc private func handleMoveUp() {
        MenuCoordinator.shared.moveSelectedTaskUp?()
    }

    @objc private func handleMoveDown() {
        MenuCoordinator.shared.moveSelectedTaskDown?()
    }

    @objc private func handleMarkCompleted() {
        MenuCoordinator.shared.markSelectedTaskCompleted?()
    }

    @objc private func handleClearCompleted() {
        MenuCoordinator.shared.clearCompletedTasks?()
    }
}

@main
struct ListlessMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let persistenceController: PersistenceController

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
        persistenceController = isUITesting ? PersistenceController(inMemory: true) : .shared
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            TaskListView(
                store: TaskStore(persistenceController: persistenceController),
                syncMonitor: persistenceController.syncMonitor
            )
            .environment(\.managedObjectContext, persistenceController.viewContext)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
