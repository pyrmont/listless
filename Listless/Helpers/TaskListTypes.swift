import Foundation

enum FocusField: Hashable {
    case task(UUID)
    case scrollView
}

enum DragState: Equatable {
    case idle
    case dragging(id: UUID, order: [UUID])
}

enum DraftTaskPlacement: Equatable {
    case prepend
    case append
}

let draftPrependRowID = UUID()
let draftAppendRowID = UUID()
