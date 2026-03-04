import UIKit

// MARK: - Menu Coordinator

/// Bridges SwiftUI view state to UIKit menu items, mirroring the macOS
/// `MenuCoordinator` pattern. `TaskListView.updateMenuCoordinator()` keeps
/// actions and enabled flags current; `KeyCaptureView` dispatches actions
/// and validates commands via the responder chain.
@MainActor
final class IOSMenuCoordinator {
    static let shared = IOSMenuCoordinator()
    private init() {}

    // Actions — set by TaskListView on each relevant state change.
    var newTask: (() -> Void)?
    var deleteTask: (() -> Void)?
    var moveUp: (() -> Void)?
    var moveDown: (() -> Void)?
    var markCompleted: (() -> Void)?

    // Enabled state — read by KeyCaptureView in validate(_:).
    var canDelete = false
    var canMoveUp = false
    var canMoveDown = false
    var canMarkCompleted = false
}

// MARK: - Menu Selectors

/// Selectors for menu item actions routed through the responder chain.
/// `KeyCaptureView` (first responder) implements these as `@objc` methods.
enum IOSMenuSelectors {
    static let newTask = #selector(IOSMenuActions.handleNewTask)
    static let deleteTask = #selector(IOSMenuActions.handleDeleteTask)
    static let moveUp = #selector(IOSMenuActions.handleMoveUp)
    static let moveDown = #selector(IOSMenuActions.handleMoveDown)
    static let markCompleted = #selector(IOSMenuActions.handleMarkCompleted)
}

/// Protocol declaring the `@objc` action methods so selectors can be
/// referenced at compile time. `KeyCaptureView` conforms to this.
@MainActor @objc protocol IOSMenuActions {
    func handleNewTask()
    func handleDeleteTask()
    func handleMoveUp()
    func handleMoveDown()
    func handleMarkCompleted()
}
