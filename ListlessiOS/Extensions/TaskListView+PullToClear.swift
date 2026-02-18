import SwiftUI

extension TaskListView {
    @ViewBuilder var pullToClearIndicatorRow: some View {
        if pullUpOffset > 0 && !completedTasks.isEmpty {
            PullToClearIndicator(pullOffset: pullUpOffset)
        }
    }
}
