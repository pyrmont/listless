import SwiftUI

extension TaskListView {
    @ViewBuilder var pullToClearIndicatorRow: some View {
        if iState.pullUpOffset > 0 && !completedTasks.isEmpty {
            PullToClearIndicator(pullOffset: iState.pullUpOffset)
        }
    }
}
