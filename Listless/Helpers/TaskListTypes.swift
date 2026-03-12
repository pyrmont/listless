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

struct FocusStateData {
    var focusedField: FocusField?
    var selectedTaskID: UUID?
    var pendingFocus: FocusField?
}

let draftPrependRowID = UUID()
let draftAppendRowID = UUID()
