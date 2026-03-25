import SwiftUI

extension ItemListView {
    @ViewBuilder var pullToClearIndicatorRow: some View {
        if pState.pullUpOffset > 0 && !completedItems.isEmpty {
            PullToClearIndicator(pullOffset: pState.pullUpOffset)
        }
    }
}
