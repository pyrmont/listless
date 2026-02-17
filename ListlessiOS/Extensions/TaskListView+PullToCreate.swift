import SwiftUI

extension TaskListView {
    @ViewBuilder var pullToCreateIndicatorRow: some View {
        if pullOffset > 0 {
            PullToCreateIndicator(pullOffset: pullOffset)
        }
    }
}
