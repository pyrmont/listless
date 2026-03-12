import Foundation

// Bridges SwiftUI view state to AppKit menu items without using SwiftUI's Commands API.
// One instance per window; AppDelegate resolves the key window's coordinator at dispatch time.
@MainActor
final class MenuCoordinator {

    // Actions — set by TaskListView on each relevant state change.
    var newTask: (() -> Void)?
    var newWindow: (() -> Void)?
    var copySelectedTask: (() -> Void)?
    var cutSelectedTask: (() -> Void)?
    var pasteAfterSelectedTask: (() -> Void)?
    var deleteSelectedTask: (() -> Void)?
    var moveSelectedTaskUp: (() -> Void)?
    var moveSelectedTaskDown: (() -> Void)?
    var markSelectedTaskCompleted: (() -> Void)?
    var clearCompletedTasks: (() -> Void)?

    // Enabled state — read by AppDelegate in menuWillOpen and validateMenuItem.
    var canCopySelectedTask = false
    var canCutSelectedTask = false
    var canPasteAfterSelectedTask = false
    var canDeleteSelectedTask = false
    var canMoveSelectedTaskUp = false
    var canMoveSelectedTaskDown = false
    var canMarkSelectedTaskCompleted = false
    var canClearCompletedTasks = false

    // Dynamic titles — read by AppDelegate in validateMenuItem.
    var markCompletedTitle: String = "Mark as Complete"
}
