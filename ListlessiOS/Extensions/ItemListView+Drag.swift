import SwiftUI

extension ItemListView {
    func handleIOSDragChanged(itemID: UUID, point: CGPoint) {
        guard let draggedID = draggedItemID,
              var order = visualOrder,
              let currentIndex = order.firstIndex(of: draggedID) else { return }

        let draggedFrame = layoutStorage.draggedRowFrame
        guard draggedFrame != .zero else { return }

        let threshold = draggedFrame.height * 0.2

        // Swap down: finger moved past the bottom edge of the dragged row
        if currentIndex < order.count - 1 && point.y > draggedFrame.maxY + threshold {
            order.swapAt(currentIndex, currentIndex + 1)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                setDragOrder(order)
            }
            return
        }

        // Swap up: finger moved past the top edge of the dragged row
        if currentIndex > 0 && point.y < draggedFrame.minY - threshold {
            order.swapAt(currentIndex, currentIndex - 1)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                setDragOrder(order)
            }
        }
    }

    func commitIOSDrag() {
        guard let draggedID = draggedItemID,
              let order = visualOrder,
              let finalIndex = order.firstIndex(of: draggedID) else {
            clearDragState()
            isDragging = false
            return
        }
        do {
            try store.moveItem(itemID: draggedID, toIndex: finalIndex)
            clearDragState()
            isDragging = false
        } catch {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                clearDragState()
                isDragging = false
            }
            presentStoreError(error)
        }
    }
}
