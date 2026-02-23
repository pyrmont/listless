import Foundation

// Bridges SwiftUI view state to AppKit menu items without using SwiftUI's Commands API.
@MainActor
final class MenuCoordinator {
    static let shared = MenuCoordinator()
    private init() {}

    // Actions — set by TaskListView on each relevant state change.
    var newTask: (() -> Void)?
    var deleteSelectedTask: (() -> Void)?
    var moveSelectedTaskUp: (() -> Void)?
    var moveSelectedTaskDown: (() -> Void)?
    var markSelectedTaskCompleted: (() -> Void)?
    var clearCompletedTasks: (() -> Void)?

    // Enabled state — read by AppDelegate in menuWillOpen and validateMenuItem.
    var canDeleteSelectedTask = false
    var canMoveSelectedTaskUp = false
    var canMoveSelectedTaskDown = false
    var canMarkSelectedTaskCompleted = false
    var canClearCompletedTasks = false

    // Dynamic titles — read by AppDelegate in validateMenuItem.
    var markCompletedTitle: String = "Mark as Completed"
}
