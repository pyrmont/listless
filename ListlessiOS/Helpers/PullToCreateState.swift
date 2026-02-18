import SwiftUI

struct PullToCreateState {
    enum Action {
        case none
        case createTask
        case collapseIndicator
    }

    var pullOffset: CGFloat = 0
    var indicatorOffset: CGFloat = 0
    var isInsertionPending: Bool = false
    var activeTaskCountBeforeCreate: Int = 0
    var isScrollInteracting: Bool = false

    var shouldShowIndicator: Bool {
        indicatorOffset > 0 || isInsertionPending
    }

    func indicatorDisplayOffset(threshold: CGFloat) -> CGFloat {
        isInsertionPending ? threshold : indicatorOffset
    }

    mutating func updatePullDistance(_ distance: CGFloat) {
        pullOffset = distance
        if isScrollInteracting {
            indicatorOffset = distance
        }
    }

    mutating func handlePhaseChange(
        from oldPhase: ScrollPhase,
        to newPhase: ScrollPhase,
        activeTaskCount: Int,
        threshold: CGFloat
    ) -> Action {
        isScrollInteracting = (newPhase == .interacting)
        guard oldPhase == .interacting, newPhase != .interacting else { return .none }

        if pullOffset >= threshold {
            activeTaskCountBeforeCreate = activeTaskCount
            isInsertionPending = true
            return .createTask
        }

        isInsertionPending = false
        return .collapseIndicator
    }

    mutating func resolvePendingInsertion(activeTaskCount: Int) -> Bool {
        guard isInsertionPending, activeTaskCount > activeTaskCountBeforeCreate else { return false }
        isInsertionPending = false
        indicatorOffset = 0
        return true
    }
}
