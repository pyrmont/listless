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

private struct PullGesturesModifier: ViewModifier {
    @Binding var pullToCreate: TaskListView.PullToCreateState
    @Binding var pullUpOffset: CGFloat
    @Binding var isDragging: Bool

    @State private var isAtBottom = false
    @State private var clearPullStartedAtBottom = false

    let activeTaskIDs: [UUID]
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
            .onScrollGeometryChange(for: Bool.self) { geo in
                // Match the same bottom inset adjustment used by the ScrollView.
                let adjustedBottomInset = geo.contentInsets.bottom - 20
                let maxOffset = max(
                    -geo.contentInsets.top,
                    geo.contentSize.height - geo.bounds.size.height + adjustedBottomInset
                )
                return geo.contentOffset.y >= (maxOffset - 1)
            } action: { _, atBottom in
                isAtBottom = atBottom
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
            .simultaneousGesture(clearCompletedPullGesture)
    }

    private func handlePullToCreateScrollPhaseChange(from oldPhase: ScrollPhase, to newPhase: ScrollPhase) {
        let action = pullToCreate.handlePhaseChange(
            from: oldPhase,
            to: newPhase,
            pullThreshold: pullCreateThreshold,
            flickThreshold: flickThreshold
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

    }

    private var clearCompletedPullGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard hasCompletedTasks, !isDragging else { return }

                if !clearPullStartedAtBottom {
                    clearPullStartedAtBottom = isAtBottom
                }
                guard clearPullStartedAtBottom else { return }

                // Use finger travel, not ScrollView rubber-band displacement.
                pullUpOffset = max(0, -value.translation.height)
            }
            .onEnded { _ in
                defer {
                    clearPullStartedAtBottom = false
                    pullUpOffset = 0
                }

                guard hasCompletedTasks, clearPullStartedAtBottom else { return }
                if pullUpOffset >= pullClearThreshold {
                    onClearCompleted()
                }
            }
    }
}

extension View {
    func pullGestures(
        pullToCreate: Binding<TaskListView.PullToCreateState>,
        pullUpOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        activeTaskIDs: [UUID],
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
                isDragging: isDragging,
                activeTaskIDs: activeTaskIDs,
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
