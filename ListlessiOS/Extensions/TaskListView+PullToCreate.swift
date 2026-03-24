import SwiftUI

extension TaskListView {

    // MARK: - Pull-to-Create Draft Helpers

    func revealPhantomRow() -> UUID {
        let taskID = draftPrependRowID

        if draftPlacement != .prepend, draftPlacement != nil {
            commitDraftTask()
        }
        clearDragState()
        draftTitle = ""
        draftPlacement = .prepend
        fState.selectedTaskID = taskID
        fState.pendingFocus = .task(taskID)
        focusedField = .task(taskID)

        return taskID
    }

    func commitPhantomRow() {
        commitDraftTask()
    }
}
