import SwiftUI
import AppKit

private enum MenuSelectors {
    static let showSettingsWindow = Selector(("showSettingsWindow:"))
    static let closeAll = Selector(("closeAll:"))
    static let undo = Selector(("undo:"))
    static let redo = Selector(("redo:"))
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        installMainMenu()
    }

    // MARK: - NSMenuItemValidation
    // AppKit calls this automatically for each item targeting self, both when the
    // menu opens and when keyboard shortcuts are evaluated.

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let coord = MenuCoordinator.shared
        switch menuItem.action {
        case #selector(handleNewWindow):      return coord.newWindow != nil
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

    @objc private func handleNewWindow() {
        MenuCoordinator.shared.newWindow?()
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

    // MARK: - Main Menu

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: MenuSelectors.showSettingsWindow,
            keyEquivalent: ","
        )
        settingsItem.target = nil
        appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu

        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")

        let hideOthersItem = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenu = NSMenu(title: "File")
        let newTaskItem = NSMenuItem(title: "New Task", action: #selector(handleNewTask), keyEquivalent: "n")
        newTaskItem.keyEquivalentModifierMask = [.command]
        newTaskItem.target = self
        fileMenu.addItem(newTaskItem)
        fileMenu.addItem(NSMenuItem.separator())

        let newWindowItem = NSMenuItem(title: "New Window", action: #selector(handleNewWindow), keyEquivalent: "n")
        newWindowItem.keyEquivalentModifierMask = [.command, .shift]
        newWindowItem.target = self
        fileMenu.addItem(newWindowItem)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let closeAllItem = NSMenuItem(title: "Close All", action: MenuSelectors.closeAll, keyEquivalent: "w")
        closeAllItem.keyEquivalentModifierMask = [.command, .option]
        closeAllItem.target = nil
        fileMenu.addItem(closeAllItem)

        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: MenuSelectors.undo, keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: MenuSelectors.redo, keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(handleDeleteTask), keyEquivalent: "\u{08}")
        deleteItem.keyEquivalentModifierMask = []
        deleteItem.target = self
        editMenu.addItem(deleteItem)

        editMenu.addItem(NSMenuItem.separator())

        let moveUpItem = NSMenuItem(title: "Move Up", action: #selector(handleMoveUp), keyEquivalent: "\u{F700}")
        moveUpItem.keyEquivalentModifierMask = [.command]
        moveUpItem.target = self
        editMenu.addItem(moveUpItem)

        let moveDownItem = NSMenuItem(title: "Move Down", action: #selector(handleMoveDown), keyEquivalent: "\u{F701}")
        moveDownItem.keyEquivalentModifierMask = [.command]
        moveDownItem.target = self
        editMenu.addItem(moveDownItem)

        let markCompletedItem = NSMenuItem(title: "Mark as Complete", action: #selector(handleMarkCompleted), keyEquivalent: " ")
        markCompletedItem.keyEquivalentModifierMask = []
        markCompletedItem.target = self
        editMenu.addItem(markCompletedItem)

        editMenu.addItem(NSMenuItem.separator())

        let clearCompletedItem = NSMenuItem(title: "Clear Completed", action: #selector(handleClearCompleted), keyEquivalent: "")
        clearCompletedItem.target = self
        editMenu.addItem(clearCompletedItem)

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let viewMenu = NSMenu(title: "View")
        let fullScreenItem = NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreenItem.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(fullScreenItem)
        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "\(appName) Help", action: #selector(NSApplication.showHelp(_:)), keyEquivalent: "?")
        let helpMenuItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
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
        .defaultSize(width: 400, height: 350)
    }
}
