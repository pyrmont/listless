import SwiftUI

extension TaskListView {
    func handleIOSDragChanged(taskID: UUID, point: CGPoint) {
        guard let draggedID = draggedTaskID,
              var order = visualOrder,
              let currentIndex = order.firstIndex(of: draggedID),
              let draggedFrame = rowFrames[draggedID] else { return }

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
        guard let draggedID = draggedTaskID,
              let order = visualOrder,
              let finalIndex = order.firstIndex(of: draggedID) else {
            clearDragState()
            isDragging = false
            return
        }
        do {
            try store.moveTask(taskID: draggedID, toIndex: finalIndex)
        } catch {
            presentStoreError(error)
        }
        clearDragState()
        isDragging = false
    }
}
