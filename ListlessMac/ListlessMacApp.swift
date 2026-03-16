import AppKit
import SwiftUI

private enum MenuSelectors {
    static let showSettingsWindow = Selector(("showSettingsWindow:"))
    static let closeAll = Selector(("closeAll:"))
    static let undo = Selector(("undo:"))
    static let redo = Selector(("redo:"))
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let persistenceController: PersistenceController
    private var syncDiagnosticsWindow: NSWindow?
    private let coordinators = NSMapTable<NSWindow, WindowCoordinator>.weakToStrongObjects()

    private var keyWindowCoordinator: WindowCoordinator? {
        guard let window = NSApp.keyWindow else { return nil }
        return coordinators.object(forKey: window)
    }

    func coordinator(for window: NSWindow) -> WindowCoordinator? {
        coordinators.object(forKey: window)
    }

    override init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
        persistenceController = isUITesting ? PersistenceController(inMemory: true) : .shared
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        installMainMenu()
        openNewWindow()
    }


    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openNewWindow()
        }
        return true
    }

    func applicationDidUnhide(_ notification: Notification) {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    // MARK: - NSMenuItemValidation
    // AppKit calls this automatically for each item targeting self, both when the
    // menu opens and when keyboard shortcuts are evaluated.

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(handleNewWindow), #selector(handleShowSyncDiagnostics):
            return true
        default:
            break
        }
        guard let coord = keyWindowCoordinator else { return false }
        switch menuItem.action {
        case #selector(selectAll(_:)):         return coord.canSelectAllTasks
        case #selector(cut(_:)):              return coord.canCutSelectedTask
        case #selector(copy(_:)):             return coord.canCopySelectedTask
        case #selector(paste(_:)):            return coord.canPasteAfterSelectedTask
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
        if NSApp.windows.filter({ $0.isVisible }).isEmpty {
            openNewWindow()
            Task { @MainActor in
                keyWindowCoordinator?.newTask?()
            }
        } else {
            keyWindowCoordinator?.newTask?()
        }
    }

    @objc func selectAll(_ sender: Any?) {
        keyWindowCoordinator?.selectAllTasks?()
    }

    @objc func cut(_ sender: Any?) {
        keyWindowCoordinator?.cutSelectedTask?()
    }

    @objc func copy(_ sender: Any?) {
        keyWindowCoordinator?.copySelectedTask?()
    }

    @objc func paste(_ sender: Any?) {
        keyWindowCoordinator?.pasteAfterSelectedTask?()
    }

    @objc private func handleDeleteTask() {
        keyWindowCoordinator?.deleteSelectedTask?()
    }

    @objc private func handleNewWindow() {
        openNewWindow()
    }

    @objc private func handleMoveUp() {
        keyWindowCoordinator?.moveSelectedTaskUp?()
    }

    @objc private func handleMoveDown() {
        keyWindowCoordinator?.moveSelectedTaskDown?()
    }

    @objc private func handleMarkCompleted() {
        keyWindowCoordinator?.markSelectedTaskCompleted?()
    }

    @objc private func handleClearCompleted() {
        keyWindowCoordinator?.clearCompletedTasks?()
    }

    @objc func handleShowSyncDiagnostics() {
        openSyncDiagnosticsWindow()
    }

    private func openNewWindow() {
        let defaultContentSize = NSSize(width: 400, height: 350)
        let windowCoordinator = WindowCoordinator()
        let rootView = TaskListView(
            store: TaskStore(persistenceController: persistenceController),
            syncMonitor: persistenceController.syncMonitor,
            windowCoordinator: windowCoordinator
        )
        .environment(\.managedObjectContext, persistenceController.viewContext)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = NSHostingController(rootView: rootView)
        window.title = "Items"
        window.setContentSize(defaultContentSize)
        window.minSize = NSSize(width: 320, height: 240)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        coordinators.setObject(windowCoordinator, forKey: window)
        let referenceWindow = NSApp.orderedWindows.first { existingWindow in
            existingWindow.isVisible && existingWindow.title == "Items"
        }
        position(window, relativeTo: referenceWindow)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        NSApp.activate()
    }

    private func position(_ window: NSWindow, relativeTo referenceWindow: NSWindow?) {
        guard let referenceWindow else {
            window.center()
            return
        }

        let offset: CGFloat = 28
        var origin = NSPoint(
            x: referenceWindow.frame.origin.x + offset,
            y: referenceWindow.frame.origin.y - offset
        )

        if let visibleFrame = referenceWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            origin.x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - window.frame.width)
            origin.y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - window.frame.height)
        }

        window.setFrameOrigin(origin)
    }

    private func openSyncDiagnosticsWindow() {
        if let window = syncDiagnosticsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let defaultContentSize = NSSize(width: 760, height: 520)
        let rootView = SyncDiagnosticsView(syncMonitor: persistenceController.syncMonitor)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = NSHostingController(rootView: rootView)
        window.title = "iCloud Diagnostics"
        window.setContentSize(defaultContentSize)
        window.minSize = NSSize(width: 480, height: 320)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        syncDiagnosticsWindow = window
        NSApp.activate()
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
        let newTaskItem = NSMenuItem(title: "New Item", action: #selector(handleNewTask), keyEquivalent: "n")
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
        let syncDiagnosticsItem = NSMenuItem(
            title: "iCloud Diagnostics",
            action: #selector(handleShowSyncDiagnostics),
            keyEquivalent: ""
        )
        syncDiagnosticsItem.target = self
        windowMenu.addItem(syncDiagnosticsItem)
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
enum ListlessMacMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
