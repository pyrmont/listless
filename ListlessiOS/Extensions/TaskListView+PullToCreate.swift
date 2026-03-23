import SwiftUI

extension TaskListView {

    // MARK: - Pull-to-Create Draft Helpers

    func revealPhantomRow() -> UUID {
        let taskID = draftPrependRowID
        let maxOffset = PullToCreateIndicator.indicatorHeight + 12

        if draftPlacement != .prepend, draftPlacement != nil {
            commitDraftTask()
        }
        clearDragState()
        draftTitle = ""
        pState.frozenOffset = -min(pState.pullToCreate.pullOffset, maxOffset)
        draftPlacement = .prepend
        DispatchQueue.main.async {
            pState.frozenOffset = 0
        }
        fState.selectedTaskID = taskID
        fState.pendingFocus = .task(taskID)
        focusedField = .task(taskID)

        return taskID
    }

    func commitPhantomRow() {
        commitDraftTask()
    }
}
