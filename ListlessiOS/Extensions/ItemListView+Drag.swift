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
            revealAdjacentItem(order: order, draggedID: draggedID, fingerY: point.y)
            return
        }

        // Swap up: finger moved past the top edge of the dragged row
        if currentIndex > 0 && point.y < draggedFrame.minY - threshold {
            order.swapAt(currentIndex, currentIndex - 1)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                setDragOrder(order)
            }
            revealAdjacentItem(order: order, draggedID: draggedID, fingerY: point.y)
            return
        }

        // No swap, but proactively scroll if finger is in an edge zone
        revealAdjacentItem(order: order, draggedID: draggedID, fingerY: point.y)
    }

    private func revealAdjacentItem(order: [UUID], draggedID: UUID, fingerY: CGFloat) {
        guard let idx = order.firstIndex(of: draggedID) else { return }

        let now = CACurrentMediaTime()
        guard now - layoutStorage.lastAutoScrollTime > 0.2 else { return }

        let screenHeight = UIScreen.main.bounds.height
        let edgeZone: CGFloat = 120

        if fingerY > screenHeight - edgeZone, idx + 1 < order.count {
            layoutStorage.lastAutoScrollTime = now
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollPosition.scrollTo(id: order[idx + 1], anchor: .bottom)
            }
        } else if fingerY < edgeZone, idx > 0 {
            layoutStorage.lastAutoScrollTime = now
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollPosition.scrollTo(id: order[idx - 1], anchor: .top)
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
