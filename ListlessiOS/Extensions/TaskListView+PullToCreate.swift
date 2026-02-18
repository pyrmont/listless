import SwiftUI

extension TaskListView {
    @ViewBuilder var pullToCreateIndicatorRow: some View {
        if pullToCreate.shouldShowIndicator {
            PullToCreateIndicator(
                pullOffset: pullToCreate.indicatorDisplayOffset(threshold: pullCreateThreshold),
                threshold: pullCreateThreshold
            )
        }
    }
}
