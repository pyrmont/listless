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
        var isScrollInteracting: Bool = false

        private var pullStartTime: CFTimeInterval = 0

        var shouldShowIndicator: Bool {
            indicatorOffset > 0 || isInsertionPending
        }

        func indicatorDisplayOffset(threshold: CGFloat) -> CGFloat {
            isInsertionPending ? threshold : indicatorOffset
        }

        mutating func updatePullDistance(_ distance: CGFloat) {
            // Skip duplicate writes to break onScrollGeometryChange re-layout cycles.
            guard pullOffset != distance else { return }
            pullOffset = distance
            if isScrollInteracting {
                indicatorOffset = distance
            }
        }

        mutating func handlePhaseChange(
            from oldPhase: ScrollPhase,
            to newPhase: ScrollPhase,
            pullThreshold: CGFloat,
            flickThreshold: CGFloat
        ) -> Action {
            if newPhase == .interacting, oldPhase != .interacting {
                pullStartTime = CACurrentMediaTime()
                // Sync in case onScrollGeometryChange fired before this
                // phase change, leaving indicatorOffset behind pullOffset.
                indicatorOffset = pullOffset
            }
            isScrollInteracting = (newPhase == .interacting)
            guard oldPhase == .interacting, newPhase != .interacting else { return .none }

            let elapsed = CACurrentMediaTime() - pullStartTime
            let isFlick = pullOffset > 0 && elapsed > 0
                && (pullOffset / elapsed) >= flickThreshold

            if pullOffset >= pullThreshold || isFlick {
                isInsertionPending = true
                return .createTask
            }

            isInsertionPending = false
            return .collapseIndicator
        }
    }
}

private struct PullGesturesModifier: ViewModifier {
    @Binding var pullToCreate: TaskListView.PullToCreateState
    @Binding var pullUpOffset: CGFloat

    @State private var isScrollInteracting = false

    let isDraftOpen: Bool
    let hasCompletedTasks: Bool
    let pullCreateThreshold: CGFloat
    let flickThreshold: CGFloat
    let pullClearThreshold: CGFloat
    let onCreateTaskAtTop: () -> UUID
    let onClearCompleted: () -> Void

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                max(0, -(geo.contentOffset.y + geo.contentInsets.top))
            } action: { _, pullDistance in
                pullToCreate.updatePullDistance(pullDistance)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                let adjustedBottomInset = geo.contentInsets.bottom - 20
                let maxOffset = max(
                    -geo.contentInsets.top,
                    geo.contentSize.height - geo.bounds.size.height + adjustedBottomInset
                )
                return max(0, geo.contentOffset.y - maxOffset)
            } action: { _, bottomOverscroll in
                guard hasCompletedTasks, isScrollInteracting else { return }
                pullUpOffset = bottomOverscroll
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                if newPhase == .interacting {
                    isScrollInteracting = true
                }

                handlePullToCreateScrollPhaseChange(from: oldPhase, to: newPhase)

                if oldPhase == .interacting, newPhase != .interacting {
                    handlePullToClearRelease()
                    isScrollInteracting = false
                }
            }
            .sensoryFeedback(
                .impact(weight: .light),
                trigger: !isDraftOpen && pullToCreate.pullOffset >= pullCreateThreshold
            ) { old, new in
                !old && new
            }
            .sensoryFeedback(.impact(weight: .light), trigger: pullUpOffset >= pullClearThreshold) { old, new in
                !old && new
            }
    }

    private func handlePullToCreateScrollPhaseChange(from oldPhase: ScrollPhase, to newPhase: ScrollPhase) {
        guard !isDraftOpen else { return }
        let action = pullToCreate.handlePhaseChange(
            from: oldPhase,
            to: newPhase,
            pullThreshold: pullCreateThreshold,
            flickThreshold: flickThreshold
        )

        guard oldPhase == .interacting, newPhase != .interacting else { return }

        switch action {
        case .createTask:
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                _ = onCreateTaskAtTop()
            }
        case .collapseIndicator:
            withAnimation(.spring(response: 0.22, dampingFraction: 1.0)) {
                pullToCreate.indicatorOffset = 0
            }
        case .none:
            break
        }
    }

    private func handlePullToClearRelease() {
        guard hasCompletedTasks, pullUpOffset >= pullClearThreshold else {
            pullUpOffset = 0
            return
        }
        pullUpOffset = 0
        onClearCompleted()
    }
}

extension View {
    func pullGestures(
        pullToCreate: Binding<TaskListView.PullToCreateState>,
        pullUpOffset: Binding<CGFloat>,
        isDraftOpen: Bool,
        hasCompletedTasks: Bool,
        pullCreateThreshold: CGFloat,
        flickThreshold: CGFloat,
        pullClearThreshold: CGFloat,
        onCreateTaskAtTop: @escaping () -> UUID,
        onClearCompleted: @escaping () -> Void
    ) -> some View {
        modifier(
            PullGesturesModifier(
                pullToCreate: pullToCreate,
                pullUpOffset: pullUpOffset,
                isDraftOpen: isDraftOpen,
                hasCompletedTasks: hasCompletedTasks,
                pullCreateThreshold: pullCreateThreshold,
                flickThreshold: flickThreshold,
                pullClearThreshold: pullClearThreshold,
                onCreateTaskAtTop: onCreateTaskAtTop,
                onClearCompleted: onClearCompleted
            )
        )
    }
}
