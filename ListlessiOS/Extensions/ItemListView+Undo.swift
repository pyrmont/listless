import SwiftUI

extension ItemListView {

    func deleteItemWithUndo(_ item: ItemEntity) {
        deleteItem(item)
        showUndoToast(message: "Item deleted")
    }

    func deleteSelectedItemWithUndo() -> KeyPress.Result {
        guard focusedField == .scrollView else {
            return .ignored
        }
        guard let currentID = fState.selectedItemID else {
            return .handled
        }
        guard let item = allItemsInDisplayOrder.first(where: { $0.id == currentID }) else {
            return .handled
        }
        deleteItemWithUndo(item)
        return .handled
    }

    func clearCompletedItemsWithUndo() {
        let ids = completedItems.map(\.id)
        guard !ids.isEmpty else { return }
        let count = ids.count
        managedObjectContext.undoManager?.beginUndoGrouping()
        do {
            try store.deleteMultiple(itemIDs: ids)
        } catch {
            presentStoreError(error)
            managedObjectContext.undoManager?.endUndoGrouping()
            return
        }
        managedObjectContext.undoManager?.endUndoGrouping()
        let noun = count == 1 ? "item" : "items"
        showUndoToast(message: "\(count) \(noun) cleared")
    }

    func showUndoToast(message: String) {
        withAnimation {
            iState.undoToast = UndoToastData(id: UUID(), message: message)
        }
    }

    func performUndo() {
        managedObjectContext.undoManager?.undo()
        do {
            try store.save()
        } catch {
            presentStoreError(error)
        }
        dismissUndoToast()
    }

    func dismissUndoToast() {
        withAnimation {
            iState.undoToast = nil
        }
    }
}
