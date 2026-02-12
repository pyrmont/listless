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
        return ZStack(alignment: .leading) {
            // Background stays in place
            swipeBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .allowsHitTesting(false)

            // Only the content moves
            content
                .offset(x: swipeOffset)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipeOffset)
                .contentShape(Rectangle())
                .background {
                    #if canImport(UIKit)
                        SwipePanGestureInstaller(
                            isEnabled: isActive && !isEditing && !isDragging,
                            onChanged: { translation in
                                handleDragChanged(
                                    horizontalTranslation: translation.x,
                                    verticalTranslation: abs(translation.y)
                                )
                            },
                            onEnded: {
                                handleDragEnded()
                            }
                        )
                    #endif
                }
        }
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
            HStack {
                Spacer()
                Image(systemName: "trash.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .padding(.trailing, 20)
            }
            .background(Color.red.opacity(backgroundOpacity(offset: swipeOffset)))
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

private struct SwipePanGestureInstaller: UIViewRepresentable {
    let isEnabled: Bool
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.onMoveToSuperview = { installerView in
            context.coordinator.attach(to: hostView(for: installerView), marker: installerView)
        }
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.attach(to: hostView(for: uiView), marker: uiView)
    }

    static func dismantleUIView(_ uiView: InstallerView, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isEnabled: isEnabled, onChanged: onChanged, onEnded: onEnded)
    }

    private func hostView(for installerView: UIView) -> UIView? {
        // Climb toward the row container (above the background host, below the ScrollView).
        var current = installerView.superview
        var candidate: UIView?

        while let view = current {
            if view is UIScrollView {
                break
            }
            candidate = view
            current = view.superview
        }

        return candidate ?? installerView.superview
    }

    final class InstallerView: UIView {
        var onMoveToSuperview: ((UIView) -> Void)?

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            onMoveToSuperview?(self)
        }

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            false
        }
    }

        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled: Bool
        var onChanged: (CGPoint) -> Void
        var onEnded: () -> Void

        private weak var attachedView: UIView?
        private weak var markerView: UIView?
        private var panRecognizer: UIPanGestureRecognizer?

        init(isEnabled: Bool, onChanged: @escaping (CGPoint) -> Void, onEnded: @escaping () -> Void) {
            self.isEnabled = isEnabled
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        func attach(to view: UIView?, marker: UIView) {
            markerView = marker

            guard let view else {
                detach()
                return
            }

            if attachedView === view {
                panRecognizer?.isEnabled = isEnabled
                return
            }

            detach()

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            pan.cancelsTouchesInView = false
            pan.delaysTouchesBegan = false
            pan.maximumNumberOfTouches = 1
            pan.isEnabled = isEnabled
            view.addGestureRecognizer(pan)

            attachedView = view
            panRecognizer = pan
        }

        func detach() {
            if let panRecognizer, let attachedView {
                attachedView.removeGestureRecognizer(panRecognizer)
            }
            panRecognizer = nil
            attachedView = nil
            markerView = nil
        }

        @objc
        private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard isEnabled else { return }
            let translation = recognizer.translation(in: recognizer.view)

            switch recognizer.state {
            case .began, .changed:
                onChanged(translation)
            case .ended, .cancelled, .failed:
                onEnded()
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard
                isEnabled,
                let pan = gestureRecognizer as? UIPanGestureRecognizer,
                let attachedView,
                let markerView
            else {
                return false
            }

            // Multiple row recognizers may be attached to a shared host view.
            // Only allow the recognizer whose row contains the touch to begin.
            let markerFrame = markerView.convert(markerView.bounds, to: attachedView)
            let touchPoint = pan.location(in: attachedView)
            return markerFrame.contains(touchPoint)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
