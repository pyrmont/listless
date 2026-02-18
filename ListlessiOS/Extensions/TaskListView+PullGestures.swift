import SwiftUI

extension TaskListView {
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

        mutating func resolvePendingInsertion(activeTaskCount: Int) {
            guard isInsertionPending, activeTaskCount > activeTaskCountBeforeCreate else { return }
            isInsertionPending = false
            indicatorOffset = 0
        }
    }
}

private struct PullCreationGestureModifier: ViewModifier {
    @Binding var pullToCreate: TaskListView.PullToCreateState
    @Binding var pullUpOffset: CGFloat

    let activeTaskCount: Int
    let hasCompletedTasks: Bool
    let pullCreateThreshold: CGFloat
    let pullClearThreshold: CGFloat
    let onCreateTaskAtTop: () -> Void
    let onClearCompleted: () -> Void

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                max(0, -(geo.contentOffset.y + geo.contentInsets.top))
            } action: { _, pullDistance in
                pullToCreate.updatePullDistance(pullDistance)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                let maxOffset = max(
                    -geo.contentInsets.top,
                    geo.contentSize.height - geo.bounds.size.height + geo.contentInsets.bottom
                )
                return max(0, geo.contentOffset.y - maxOffset)
            } action: { _, pullDistance in
                pullUpOffset = pullDistance
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                handlePullToCreateScrollPhaseChange(from: oldPhase, to: newPhase)
            }
            .onChange(of: activeTaskCount) { _, newCount in
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    pullToCreate.resolvePendingInsertion(activeTaskCount: newCount)
                }
            }
            .sensoryFeedback(
                .impact(weight: .medium),
                trigger: pullToCreate.pullOffset >= pullCreateThreshold
            ) { old, new in
                !old && new
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: pullUpOffset >= pullClearThreshold) { old, new in
                !old && new
            }
    }

    private func handlePullToCreateScrollPhaseChange(from oldPhase: ScrollPhase, to newPhase: ScrollPhase) {
        let action = pullToCreate.handlePhaseChange(
            from: oldPhase,
            to: newPhase,
            activeTaskCount: activeTaskCount,
            threshold: pullCreateThreshold
        )

        guard oldPhase == .interacting, newPhase != .interacting else { return }

        switch action {
        case .createTask:
            var transaction = Transaction(animation: .spring(response: 0.28, dampingFraction: 0.9))
            transaction.disablesAnimations = false
            withTransaction(transaction) {
                onCreateTaskAtTop()
            }
        case .collapseIndicator:
            withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) {
                pullToCreate.indicatorOffset = 0
            }
        case .none:
            break
        }

        if pullUpOffset >= pullClearThreshold && hasCompletedTasks {
            onClearCompleted()
        }
        pullUpOffset = 0
    }
}

extension View {
    func pullCreationGesture(
        pullToCreate: Binding<TaskListView.PullToCreateState>,
        pullUpOffset: Binding<CGFloat>,
        activeTaskCount: Int,
        hasCompletedTasks: Bool,
        pullCreateThreshold: CGFloat,
        pullClearThreshold: CGFloat,
        onCreateTaskAtTop: @escaping () -> Void,
        onClearCompleted: @escaping () -> Void
    ) -> some View {
        modifier(
            PullCreationGestureModifier(
                pullToCreate: pullToCreate,
                pullUpOffset: pullUpOffset,
                activeTaskCount: activeTaskCount,
                hasCompletedTasks: hasCompletedTasks,
                pullCreateThreshold: pullCreateThreshold,
                pullClearThreshold: pullClearThreshold,
                onCreateTaskAtTop: onCreateTaskAtTop,
                onClearCompleted: onClearCompleted
            )
        )
    }
}
