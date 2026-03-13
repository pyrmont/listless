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
    var pendingFocus: FocusField?

    // MARK: - Selection

    /// The full set of selected task IDs (supports multi-select on macOS).
    private(set) var selectedTaskIDs: Set<UUID> = []

    /// The start of a Shift+Arrow range selection. Stays fixed while the
    /// cursor moves via repeated Shift+Arrow presses.
    var anchorTaskID: UUID?

    /// The current cursor position. During single-select this equals the
    /// anchor. During Shift+Arrow it tracks the moving end of the range.
    private(set) var cursorTaskID: UUID?

    /// Single-select convenience. Getting returns the cursor (i.e. the
    /// position plain Arrow keys navigate from); setting resets to a
    /// single-element (or empty) selection, keeping all existing call
    /// sites working without modification.
    var selectedTaskID: UUID? {
        get { cursorTaskID }
        set {
            anchorTaskID = newValue
            cursorTaskID = newValue
            selectedTaskIDs = newValue.map { Set([$0]) } ?? []
        }
    }

    func isTaskSelected(_ id: UUID) -> Bool {
        selectedTaskIDs.contains(id)
    }

    var hasMultipleSelection: Bool {
        selectedTaskIDs.count > 1
    }

    /// Extend or contract the selection from the anchor to `targetID`,
    /// selecting all tasks between them in `displayOrder`.
    mutating func extendSelection(to targetID: UUID, displayOrder: [UUID]) {
        guard let anchorID = anchorTaskID,
            let anchorIndex = displayOrder.firstIndex(of: anchorID),
            let targetIndex = displayOrder.firstIndex(of: targetID)
        else {
            return
        }
        let range =
            anchorIndex <= targetIndex
            ? anchorIndex...targetIndex
            : targetIndex...anchorIndex
        selectedTaskIDs = Set(range.map { displayOrder[$0] })
        cursorTaskID = targetID
    }
}

let draftPrependRowID = UUID()
let draftAppendRowID = UUID()
