import SwiftUI

extension TaskListView {
    @ToolbarContentBuilder
    var platformToolbar: some ToolbarContent {
        // No toolbar on iOS - users interact with tasks directly
        // (tap to toggle, swipe to delete, tap background to create)
        ToolbarItemGroup {}
    }
}
