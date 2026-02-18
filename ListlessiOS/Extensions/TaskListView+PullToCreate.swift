import SwiftUI

extension TaskListView {
    @ViewBuilder var pullToCreateIndicatorRow: some View {
        if createIndicatorOffset > 0 || isCreateInsertionPending {
            PullToCreateIndicator(
                pullOffset: isCreateInsertionPending ? pullCreateThreshold : createIndicatorOffset
            )
        }
    }
}
