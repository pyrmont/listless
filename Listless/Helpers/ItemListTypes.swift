import Foundation

enum FocusField: Hashable {
    case item(UUID)
    case scrollView
}

let pageNavigationSize = 10

enum DragState: Equatable {
    case idle
    case dragging(id: UUID, order: [UUID])
}

enum DraftItemPlacement: Equatable {
    case prepend
    case append
}

struct FocusStateData {
    var focusedField: FocusField?
    var pendingFocus: FocusField?

    // MARK: - Selection

    /// The full set of selected item IDs (supports multi-select on macOS).
    private(set) var selectedItemIDs: Set<UUID> = []

    /// The start of a Shift+Arrow range selection. Stays fixed while the
    /// cursor moves via repeated Shift+Arrow presses.
    var anchorItemID: UUID?

    /// The current cursor position. During single-select this equals the
    /// anchor. During Shift+Arrow it tracks the moving end of the range.
    private(set) var cursorItemID: UUID?

    /// Selected items outside the active anchor–cursor range, preserved
    /// across Shift+Arrow operations after a Cmd+Click toggle.
    private(set) var inactiveSelections: Set<UUID> = []

    /// Single-select convenience. Getting returns the cursor (i.e. the
    /// position plain Arrow keys navigate from); setting resets to a
    /// single-element (or empty) selection, keeping all existing call
    /// sites working without modification.
    var selectedItemID: UUID? {
        get { cursorItemID }
        set {
            anchorItemID = newValue
            cursorItemID = newValue
            selectedItemIDs = newValue.map { Set([$0]) } ?? []
            inactiveSelections = []
        }
    }

    func isItemSelected(_ id: UUID) -> Bool {
        selectedItemIDs.contains(id)
    }

    var hasMultipleSelection: Bool {
        selectedItemIDs.count > 1
    }

    /// Select all items in display order, anchoring at the first and
    /// placing the cursor at the last.
    mutating func selectAll(displayOrder: [UUID]) {
        guard !displayOrder.isEmpty else { return }
        anchorItemID = displayOrder.first
        cursorItemID = displayOrder.last
        selectedItemIDs = Set(displayOrder)
        inactiveSelections = []
    }

    /// Toggle a single item in/out of the selection (Cmd+Click).
    /// Sets anchor to the item below the toggled item in display order.
    /// When deselecting, cursor stays at its previous position so
    /// Shift+Arrow contracts from the far end. When adding, cursor
    /// resets to anchor so the active range stays small and other
    /// selections are preserved as inactive.
    mutating func toggleSelection(itemID: UUID, displayOrder: [UUID]) {
        guard let toggledIndex = displayOrder.firstIndex(of: itemID) else { return }

        let wasSelected = selectedItemIDs.contains(itemID)
        if wasSelected {
            selectedItemIDs.remove(itemID)
        } else {
            selectedItemIDs.insert(itemID)
        }

        guard !selectedItemIDs.isEmpty else {
            anchorItemID = nil
            cursorItemID = nil
            inactiveSelections = []
            return
        }

        // Anchor = item below the toggled item (or self if at bottom).
        anchorItemID =
            toggledIndex + 1 < displayOrder.count
            ? displayOrder[toggledIndex + 1]
            : displayOrder[toggledIndex]

        if wasSelected {
            // Deselecting: cursor stays so Shift+Arrow contracts from
            // the far end of the remaining selection.
            if cursorItemID == nil {
                cursorItemID = anchorItemID
            }
        } else {
            // Adding: cursor resets to anchor so the active range is
            // small, preserving other selections as inactive.
            cursorItemID = anchorItemID
        }

        recomputeInactiveSelections(displayOrder: displayOrder)
    }

    /// Extend or contract the selection from the anchor to `targetID`,
    /// selecting all items between them in `displayOrder`. Inactive
    /// selections are preserved and merged when they become adjacent
    /// to the active range.
    mutating func extendSelection(to targetID: UUID, displayOrder: [UUID]) {
        guard let anchorID = anchorItemID,
            let anchorIndex = displayOrder.firstIndex(of: anchorID),
            let targetIndex = displayOrder.firstIndex(of: targetID)
        else {
            return
        }
        let lo = min(anchorIndex, targetIndex)
        let hi = max(anchorIndex, targetIndex)
        let activeRange = Set(displayOrder[lo...hi])
        selectedItemIDs = inactiveSelections.union(activeRange)
        cursorItemID = targetID
        mergeAdjacentInactiveSelections(displayOrder: displayOrder)
    }

    /// Remove IDs from selection state that are no longer in display order.
    /// Call after deleting items to prevent ghost selections.
    mutating func pruneDeletedItems(displayOrder: [UUID]) {
        let valid = Set(displayOrder)
        selectedItemIDs.formIntersection(valid)
        inactiveSelections.formIntersection(valid)
        if let id = anchorItemID, !valid.contains(id) {
            anchorItemID = nil
        }
        if let id = cursorItemID, !valid.contains(id) {
            cursorItemID = nil
        }
        // If the cursor was pruned, fall back to anchor or first selected.
        if cursorItemID == nil, !selectedItemIDs.isEmpty {
            cursorItemID = anchorItemID ?? selectedItemIDs.first
        }
        if selectedItemIDs.isEmpty {
            anchorItemID = nil
            cursorItemID = nil
            inactiveSelections = []
        }
    }

    // MARK: - Private Helpers

    /// Partition `selectedItemIDs` into those inside vs outside the
    /// anchor–cursor range.
    private mutating func recomputeInactiveSelections(displayOrder: [UUID]) {
        guard let anchorID = anchorItemID, let cursorID = cursorItemID,
            let anchorIndex = displayOrder.firstIndex(of: anchorID),
            let cursorIndex = displayOrder.firstIndex(of: cursorID)
        else {
            inactiveSelections = []
            return
        }
        let lo = min(anchorIndex, cursorIndex)
        let hi = max(anchorIndex, cursorIndex)
        let activeRange = Set(displayOrder[lo...hi])
        inactiveSelections = selectedItemIDs.subtracting(activeRange)
    }

    /// When the active range becomes adjacent to inactive selections,
    /// absorb them: clear the merged items from `inactiveSelections`
    /// and jump the cursor to the far end of the merged region (away
    /// from the anchor).
    private mutating func mergeAdjacentInactiveSelections(displayOrder: [UUID]) {
        guard !inactiveSelections.isEmpty,
            let anchorID = anchorItemID,
            let anchorIndex = displayOrder.firstIndex(of: anchorID),
            let cursorID = cursorItemID,
            let cursorIndex = displayOrder.firstIndex(of: cursorID)
        else {
            return
        }

        var lo = min(anchorIndex, cursorIndex)
        var hi = max(anchorIndex, cursorIndex)
        var mergedIDs: Set<UUID> = []
        var changed = true

        while changed {
            changed = false
            for inactiveID in inactiveSelections where !mergedIDs.contains(inactiveID) {
                guard let idx = displayOrder.firstIndex(of: inactiveID) else { continue }
                if idx == lo - 1 || idx == hi + 1 || (idx >= lo && idx <= hi) {
                    if idx < lo { lo = idx }
                    if idx > hi { hi = idx }
                    mergedIDs.insert(inactiveID)
                    changed = true
                }
            }
        }

        guard !mergedIDs.isEmpty else { return }

        inactiveSelections.subtract(mergedIDs)

        if cursorIndex <= anchorIndex {
            cursorItemID = displayOrder[lo]
        } else {
            cursorItemID = displayOrder[hi]
        }

        selectedItemIDs = inactiveSelections.union(Set(displayOrder[lo...hi]))
    }
}

let draftPrependRowID = UUID()
let draftAppendRowID = UUID()
