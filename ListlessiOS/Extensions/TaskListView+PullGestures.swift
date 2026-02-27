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
        var pendingTaskID: UUID?
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
            threshold: CGFloat
        ) -> Action {
            isScrollInteracting = (newPhase == .interacting)
            guard oldPhase == .interacting, newPhase != .interacting else { return .none }

            if pullOffset >= threshold {
                isInsertionPending = true
                pendingTaskID = nil
                return .createTask
            }

            isInsertionPending = false
            pendingTaskID = nil
            return .collapseIndicator
        }

        mutating func resolvePendingInsertion(activeTaskIDs: [UUID]) {
            guard isInsertionPending, let pendingTaskID else { return }
            guard activeTaskIDs.contains(pendingTaskID) else { return }
            isInsertionPending = false
            self.pendingTaskID = nil
            indicatorOffset = 0
        }
    }
}

private struct PullCreationGestureModifier: ViewModifier {
    @Binding var pullToCreate: TaskListView.PullToCreateState
    @Binding var pullUpOffset: CGFloat

    let activeTaskIDs: [UUID]
    let hasCompletedTasks: Bool
    let pullCreateThreshold: CGFloat
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
                // Subtract the 20pt bottom content margin (set on ScrollView in TaskListView)
                // so it doesn't create a dead zone before overscroll registers.
                let adjustedBottomInset = geo.contentInsets.bottom - 20
                let maxOffset = max(
                    -geo.contentInsets.top,
                    geo.contentSize.height - geo.bounds.size.height + adjustedBottomInset
                )
                return max(0, geo.contentOffset.y - maxOffset)
            } action: { _, pullDistance in
                pullUpOffset = pullDistance
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                handlePullToCreateScrollPhaseChange(from: oldPhase, to: newPhase)
            }
            .onChange(of: activeTaskIDs) { _, newIDs in
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    pullToCreate.resolvePendingInsertion(activeTaskIDs: newIDs)
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
            threshold: pullCreateThreshold
        )

        guard oldPhase == .interacting, newPhase != .interacting else { return }

        switch action {
        case .createTask:
            var transaction = Transaction(animation: .spring(response: 0.28, dampingFraction: 0.9))
            transaction.disablesAnimations = false
            var createdTaskID: UUID?
            withTransaction(transaction) {
                createdTaskID = onCreateTaskAtTop()
            }
            if let createdTaskID {
                pullToCreate.pendingTaskID = createdTaskID
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
        activeTaskIDs: [UUID],
        hasCompletedTasks: Bool,
        pullCreateThreshold: CGFloat,
        pullClearThreshold: CGFloat,
        onCreateTaskAtTop: @escaping () -> UUID,
        onClearCompleted: @escaping () -> Void
    ) -> some View {
        modifier(
            PullCreationGestureModifier(
                pullToCreate: pullToCreate,
                pullUpOffset: pullUpOffset,
                activeTaskIDs: activeTaskIDs,
                hasCompletedTasks: hasCompletedTasks,
                pullCreateThreshold: pullCreateThreshold,
                pullClearThreshold: pullClearThreshold,
                onCreateTaskAtTop: onCreateTaskAtTop,
                onClearCompleted: onClearCompleted
            )
        )
    }
}
