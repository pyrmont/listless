import Foundation

// Bridges SwiftUI view state to AppKit without using SwiftUI's Commands API.
// One instance per window; AppDelegate resolves the key window's coordinator at dispatch time.
@MainActor
final class WindowCoordinator {

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
    var selectAllTasks: (() -> Void)?
    var clearCompletedTasks: (() -> Void)?

    // Enabled state — read by AppDelegate in menuWillOpen and validateMenuItem.
    var canSelectAllTasks = false
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

    // Focus gating — checked by ClickableNSTextField.acceptsFirstResponder
    // to prevent AppKit's key-view loop from focusing the wrong text field
    // during SwiftUI reconciliation. When non-nil, only the text field
    // matching this target may accept first responder.
    var allowedFocusTarget: FocusField?
}
