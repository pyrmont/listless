import SwiftUI

extension ItemListView {
    @ToolbarContentBuilder
    var platformToolbar: some ToolbarContent {
        // No toolbar on iOS - users interact with items directly
        // (tap to toggle, swipe to delete, tap background to create)
        ToolbarItemGroup {}
    }
}
