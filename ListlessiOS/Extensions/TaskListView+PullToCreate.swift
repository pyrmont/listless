import SwiftUI

extension TaskListView {

    // MARK: - Pull-to-Create Draft Helpers

    func revealPhantomRow() -> UUID {
        return createNewTaskAtTop()
    }

    func commitPhantomRow() {
        commitDraftTask()
    }
}
