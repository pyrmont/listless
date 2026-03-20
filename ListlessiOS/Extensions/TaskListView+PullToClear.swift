import SwiftUI

extension TaskListView {
    @ViewBuilder var pullToClearIndicatorRow: some View {
        if pState.pullUpOffset > 0 && !completedTasks.isEmpty {
            PullToClearIndicator(pullOffset: pState.pullUpOffset)
        }
    }
}
