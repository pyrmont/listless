import Foundation

// Bridges SwiftUI view state to AppKit without using SwiftUI's Commands API.
// One instance per window; AppDelegate resolves the key window's coordinator at dispatch time.
@MainActor
final class WindowCoordinator {

    // Actions — set by ItemListView on each relevant state change.
    var newItem: (() -> Void)?
    var newWindow: (() -> Void)?
    var copySelectedItem: (() -> Void)?
    var cutSelectedItem: (() -> Void)?
    var pasteAfterSelectedItem: (() -> Void)?
    var deleteSelectedItem: (() -> Void)?
    var moveSelectedItemUp: (() -> Void)?
    var moveSelectedItemDown: (() -> Void)?
    var markSelectedItemCompleted: (() -> Void)?
    var selectAllItems: (() -> Void)?
    var clearCompletedItems: (() -> Void)?

    // Enabled state — read by AppDelegate in menuWillOpen and validateMenuItem.
    var canSelectAllItems = false
    var canCopySelectedItem = false
    var canCutSelectedItem = false
    var canPasteAfterSelectedItem = false
    var canDeleteSelectedItem = false
    var canMoveSelectedItemUp = false
    var canMoveSelectedItemDown = false
    var canMarkSelectedItemCompleted = false
    var canClearCompletedItems = false

    // Dynamic titles — read by AppDelegate in validateMenuItem.
    var markCompletedTitle: String = "Mark as Complete"

    // Focus gating — checked by ClickableNSTextField.acceptsFirstResponder
    // to prevent AppKit's key-view loop from focusing the wrong text field
    // during SwiftUI reconciliation. When non-nil, only the text field
    // matching this target may accept first responder.
    var allowedFocusTarget: FocusField?
}
