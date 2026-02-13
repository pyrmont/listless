import SwiftUI
import UIKit

extension View {
    func taskSwipeGesture(
        isActive: Bool,
        isEditing: Bool,
        isDragging: Bool,
        swipeOffset: Binding<CGFloat>,
        swipeDirection: Binding<TaskRowSwipeGesture.SwipeDirection>,
        isTriggered: Binding<Bool>,
        onComplete: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onSwipeActiveChanged: @escaping (Bool) -> Void = { _ in }
    ) -> some View {
        self.modifier(
            TaskRowSwipeGesture(
                isActive: isActive,
                isEditing: isEditing,
                isDragging: isDragging,
                swipeOffset: swipeOffset,
                swipeDirection: swipeDirection,
                isTriggered: isTriggered,
                onComplete: onComplete,
                onDelete: onDelete,
                onSwipeActiveChanged: onSwipeActiveChanged
            ))
    }
}

struct TaskRowSwipeGesture: ViewModifier {
    let isActive: Bool
    let isEditing: Bool
    let isDragging: Bool
    @Binding var swipeOffset: CGFloat
    @Binding var swipeDirection: SwipeDirection
    @Binding var isTriggered: Bool
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onSwipeActiveChanged: (Bool) -> Void

    enum SwipeDirection: Equatable {
        case left
        case right
        case none
    }

    private let completeThreshold: CGFloat = 40  // Pixels to swipe right before triggering complete
    private let deleteThreshold: CGFloat = 80  // Pixels to swipe left before triggering delete
    private let horizontalBufferPt: CGFloat = 10  // Horizontal movement must exceed vertical by this amount
    private let offsetDamping: CGFloat = 0.9  // Damping factor for responsive feel

    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            // Background stays in place
            swipeBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .allowsHitTesting(false)

            // Only the content moves
            content
                .offset(x: swipeOffset)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipeOffset)
                .contentShape(Rectangle())
        }
        .gesture(
            SwipePanGesture(
                onChanged: { translation in
                    guard isActive, !isEditing, !isDragging else { return }
                    handleDragChanged(
                        horizontalTranslation: translation.x,
                        verticalTranslation: abs(translation.y)
                    )
                },
                onEnded: {
                    handleDragEnded()
                }
            )
        )
        .onDisappear {
            resetSwipeState()
        }
    }

    @ViewBuilder
    private var swipeBackground: some View {
        if swipeDirection == .right {
            // Complete action — plain green background
            Color.green.opacity(backgroundOpacity(offset: swipeOffset))
        } else if swipeDirection == .left {
            // Delete action (red background, trash icon)
            Color.red.opacity(backgroundOpacity(offset: swipeOffset))
                .overlay {
                    HStack {
                        Spacer()
                        Image(systemName: "trash.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .padding(.trailing, 20)
                    }
                }
        }
    }

    private func handleDragChanged(horizontalTranslation: CGFloat, verticalTranslation: CGFloat) {
        // Require horizontal > vertical + buffer to activate swipe
        guard abs(horizontalTranslation) > verticalTranslation + horizontalBufferPt else {
            return
        }

        // Determine direction and notify that swipe is active
        if swipeDirection == .none {
            onSwipeActiveChanged(true)
        }

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

    private func triggerAction(action: @escaping () -> Void) {
        isTriggered = true

        // Trigger haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Execute action after a brief delay to show visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            action()
        }
    }

    private func resetSwipeState() {
        if swipeDirection != .none {
            onSwipeActiveChanged(false)
        }
        swipeOffset = 0
        swipeDirection = .none
        isTriggered = false
    }

    private func backgroundOpacity(offset: CGFloat) -> CGFloat {
        let threshold = offset >= 0 ? completeThreshold : deleteThreshold
        return min(abs(offset) / threshold, 1.0)
    }
}

// MARK: - UIKit Pan Gesture via UIGestureRecognizerRepresentable

/// A UIPanGestureRecognizer bridged into SwiftUI. Each row gets its own
/// recognizer; SwiftUI manages the lifecycle automatically — no manual
/// UIView host-finding or marker-based hit-testing needed.
private struct SwipePanGesture: UIGestureRecognizerRepresentable {
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UIPanGestureRecognizer, context: Context
    ) {
        switch recognizer.state {
        case .began, .changed:
            onChanged(recognizer.translation(in: recognizer.view))
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

