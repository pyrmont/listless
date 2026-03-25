import SwiftUI

extension ItemListView {

    // MARK: - Pull-to-Create Draft Helpers

    func revealPhantomRow() -> UUID {
        let itemID = draftPrependRowID

        if draftPlacement != .prepend, draftPlacement != nil {
            commitDraftItem()
        }
        clearDragState()
        draftTitle = ""
        draftPlacement = .prepend
        fState.selectedItemID = itemID
        fState.pendingFocus = .item(itemID)
        focusedField = .item(itemID)

        return itemID
    }

    func commitPhantomRow() {
        commitDraftItem()
    }
}
