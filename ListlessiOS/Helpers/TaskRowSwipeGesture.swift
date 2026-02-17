import SwiftUI

extension View {
    func taskSwipeGesture(
        isDragging: Binding<Bool>,
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
    @Binding var swipeOffset: CGFloat
    @Binding var swipeDirection: SwipeDirection
    @Binding var isTriggered: Bool
    let completeColor: Color
    let onComplete: () -> Void
    let onDelete: () -> Void

    @State private var hapticTrigger = false

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
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onChanged { value in
                    guard !isDragging else { return }
                    handleDragChanged(
                        horizontalTranslation: value.translation.width,
                        verticalTranslation: abs(value.translation.height)
                    )
                }
                .onEnded { _ in
                    handleDragEnded()
                },
            including: isDragging ? .none : .all
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

    private func handleDragChanged(horizontalTranslation: CGFloat, verticalTranslation: CGFloat) {
        // Require horizontal > vertical + buffer to activate swipe
        guard abs(horizontalTranslation) > verticalTranslation + horizontalBufferPt else {
            return
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
    }

    private func backgroundOpacity(offset: CGFloat) -> CGFloat {
        let threshold = offset >= 0 ? completeThreshold : deleteThreshold
        return min(abs(offset) / threshold, 1.0)
    }
}
