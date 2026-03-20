import SwiftUI

extension View {
    func taskSwipeGesture(
        isDragging: Binding<Bool>,
        isSwiping: Binding<Bool>,
        swipeOffset: Binding<CGFloat>,
        swipeDirection: Binding<TaskRowSwipeGesture.SwipeDirection>,
        isTriggered: Binding<Bool>,
        completeColor: Color = .green,
        onComplete: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        self.modifier(
            TaskRowSwipeGesture(
                isDragging: isDragging,
                isSwiping: isSwiping,
                swipeOffset: swipeOffset,
                swipeDirection: swipeDirection,
                isTriggered: isTriggered,
                completeColor: completeColor,
                onComplete: onComplete,
                onDelete: onDelete
            ))
    }
}

struct TaskRowSwipeGesture: ViewModifier {
    @Binding var isDragging: Bool
    @Binding var isSwiping: Bool
    @Binding var swipeOffset: CGFloat
    @Binding var swipeDirection: SwipeDirection
    @Binding var isTriggered: Bool
    let completeColor: Color
    let onComplete: () -> Void
    let onDelete: () -> Void

    @State private var hapticTrigger = false
    @State private var activeGestureAxis: ActiveGestureAxis = .undecided

    enum SwipeDirection: Equatable {
        case left
        case right
        case none
    }

    private enum ActiveGestureAxis {
        case undecided
        case horizontal
        case vertical
    }

    private let completeThreshold: CGFloat = 40
    private let deleteThreshold: CGFloat = 80
    private let horizontalBufferPt: CGFloat = 10
    private let offsetDamping: CGFloat = 0.9

    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            // Background stays in place
            swipeBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .allowsHitTesting(false)

            // Only the content moves
            content
                .offset(x: swipeOffset)
                .contentShape(Rectangle())
        }
        .applySwipeGesture(
            isDragging: isDragging,
            onChanged: { translation in
                guard !isDragging else { return }
                updateActiveGestureAxis(
                    horizontalTranslation: translation.width,
                    verticalTranslation: abs(translation.height)
                )
                guard activeGestureAxis == .horizontal else { return }
                handleDragChanged(horizontalTranslation: translation.width)
            },
            onEnded: {
                handleDragEnded()
            }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .onDisappear {
            resetSwipeState()
        }
    }

    @ViewBuilder
    private var swipeBackground: some View {
        if swipeDirection == .right {
            // Complete action — accent color background
            completeColor.opacity(backgroundOpacity(offset: swipeOffset))
        } else if swipeDirection == .left {
            // Delete action (red background, trash icon)
            Color.red.opacity(backgroundOpacity(offset: swipeOffset))
                .overlay {
                    HStack {
                        Spacer()
                        Image(systemName: "trash.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(isTriggered ? .black : .white)
                            .padding(.trailing, 20)
                    }
                }
        }
    }

    private func handleDragChanged(horizontalTranslation: CGFloat) {
        if horizontalTranslation > 0 {
            swipeDirection = .right
        } else if horizontalTranslation < 0 {
            swipeDirection = .left
        }

        // Update offset with damping
        swipeOffset = horizontalTranslation * offsetDamping

        // Track whether threshold is currently crossed — reversible until release
        if swipeDirection == .right {
            isTriggered = swipeOffset >= completeThreshold
        } else if swipeDirection == .left {
            isTriggered = abs(swipeOffset) >= deleteThreshold
        }
    }

    private func handleDragEnded() {
        defer {
            activeGestureAxis = .undecided
            isSwiping = false
        }

        guard !isDragging else {
            // A drag-reorder started during or after this swipe — spring back, no action.
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                resetSwipeState()
            }
            return
        }
        if isTriggered {
            if swipeDirection == .right {
                // Complete: spring back and let SwiftUI animate the row to the completed section
                triggerAction(action: onComplete)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    resetSwipeState()
                }
            } else {
                // Delete: slide off screen
                triggerAction(action: onDelete)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    swipeOffset = -400
                }
            }
        } else {
            // Released below threshold — spring back with no action
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                resetSwipeState()
            }
        }
    }

    private func triggerAction(action: () -> Void) {
        isTriggered = true
        hapticTrigger.toggle()
        action()
    }

    private func resetSwipeState() {
        swipeOffset = 0
        swipeDirection = .none
        isTriggered = false
        isSwiping = false
        activeGestureAxis = .undecided
    }

    private func backgroundOpacity(offset: CGFloat) -> CGFloat {
        let threshold = offset >= 0 ? completeThreshold : deleteThreshold
        return min(abs(offset) / threshold, 1.0)
    }

    private func updateActiveGestureAxis(horizontalTranslation: CGFloat, verticalTranslation: CGFloat) {
        guard activeGestureAxis == .undecided else { return }

        if abs(horizontalTranslation) > verticalTranslation + horizontalBufferPt {
            activeGestureAxis = .horizontal
            isSwiping = true
        } else if verticalTranslation > abs(horizontalTranslation) + horizontalBufferPt {
            activeGestureAxis = .vertical
        }
    }
}

// MARK: - UIGestureRecognizerRepresentable swipe gesture

/// On iOS 26, `.simultaneousGesture(DragGesture())` on a child view blocks the
/// ancestor ScrollView's scrolling. This uses a `UILongPressGestureRecognizer`
/// (with zero press duration and infinite allowable movement) as a pan substitute,
/// applied via `UIGestureRecognizerRepresentable`. The gesture delegate returns
/// `shouldRecognizeSimultaneouslyWith: true` so scrolling is preserved.
private extension View {
    func applySwipeGesture(
        isDragging: Bool,
        onChanged: @escaping (CGSize) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        self.gesture(
            SimultaneousSwipeGesture(
                onChanged: { _, translation in
                    guard !isDragging else { return }
                    onChanged(translation)
                },
                onEnded: { _, _ in
                    guard !isDragging else { return }
                    onEnded()
                }
            )
        )
    }
}

private struct SimultaneousSwipeGesture: UIGestureRecognizerRepresentable {
    let onChanged: (UILongPressGestureRecognizer, CGSize) -> Void
    let onEnded: (UILongPressGestureRecognizer, CGSize) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.0
        recognizer.allowableMovement = CGFloat.greatestFiniteMagnitude
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UILongPressGestureRecognizer, context: Context
    ) {
        switch recognizer.state {
        case .began:
            context.coordinator.startLocation = recognizer.location(in: recognizer.view)

        case .changed:
            let location = recognizer.location(in: recognizer.view)
            let translation = CGSize(
                width: location.x - context.coordinator.startLocation.x,
                height: location.y - context.coordinator.startLocation.y
            )
            onChanged(recognizer, translation)

        case .ended, .cancelled:
            let location = recognizer.location(in: recognizer.view)
            let translation = CGSize(
                width: location.x - context.coordinator.startLocation.x,
                height: location.y - context.coordinator.startLocation.y
            )
            context.coordinator.startLocation = .zero
            onEnded(recognizer, translation)

        default:
            break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var startLocation: CGPoint = .zero

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
