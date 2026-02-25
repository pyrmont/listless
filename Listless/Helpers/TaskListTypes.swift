import Foundation

enum FocusField: Hashable {
    case task(UUID)
    case scrollView
}

enum DragState: Equatable {
    case idle
    case dragging(id: UUID, order: [UUID])
}
