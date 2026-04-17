import UIKit

// MARK: - Menu Coordinator

/// Bridges SwiftUI view state to UIKit menu items, mirroring the macOS
/// `MenuCoordinator` pattern. `ItemListView.updateMenuCoordinator()` keeps
/// actions and enabled flags current; `KeyCaptureView` dispatches actions
/// and validates commands via the responder chain.
@MainActor
final class IOSMenuCoordinator {
    static let shared = IOSMenuCoordinator()
    private init() {}

    // Actions — set by ItemListView on each relevant state change.
    var newItem: (() -> Void)?
    var deleteItem: (() -> Void)?
    var moveUp: (() -> Void)?
    var moveDown: (() -> Void)?
    var markCompleted: (() -> Void)?
    var navigatePageUp: (() -> Void)?
    var navigatePageDown: (() -> Void)?
    var navigateToFirst: (() -> Void)?
    var navigateToLast: (() -> Void)?

    // Enabled state — read by KeyCaptureView in validate(_:).
    var canDelete = false
    var canMoveUp = false
    var canMoveDown = false
    var canMarkCompleted = false

    // Dynamic title — read by KeyCaptureView in validate(_:).
    var markCompletedTitle: String = "Mark as Complete"
}

// MARK: - Menu Selectors

/// Selectors for menu item actions routed through the responder chain.
/// `KeyCaptureView` (first responder) implements these as `@objc` methods.
enum IOSMenuSelectors {
    static let newItem = #selector(IOSMenuActions.handleNewItem)
    static let deleteItem = #selector(IOSMenuActions.handleDeleteItem)
    static let moveUp = #selector(IOSMenuActions.handleMoveUp)
    static let moveDown = #selector(IOSMenuActions.handleMoveDown)
    static let markCompleted = #selector(IOSMenuActions.handleMarkCompleted)
    static let navigatePageUp = #selector(IOSMenuActions.handleNavigatePageUp)
    static let navigatePageDown = #selector(IOSMenuActions.handleNavigatePageDown)
    static let navigateToFirst = #selector(IOSMenuActions.handleNavigateToFirst)
    static let navigateToLast = #selector(IOSMenuActions.handleNavigateToLast)
}

/// Protocol declaring the `@objc` action methods so selectors can be
/// referenced at compile time. `KeyCaptureView` conforms to this.
@MainActor @objc protocol IOSMenuActions {
    func handleNewItem()
    func handleDeleteItem()
    func handleMoveUp()
    func handleMoveDown()
    func handleMarkCompleted()
    func handleNavigatePageUp()
    func handleNavigatePageDown()
    func handleNavigateToFirst()
    func handleNavigateToLast()
}
