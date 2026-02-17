import SwiftUI
import UIKit

extension View {
    func taskDragGesture(
        isActive: Bool,
        taskID: UUID,
        onDragStart: @escaping () -> Void,
        onDragChanged: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping () -> Void
    ) -> some View {
        self.modifier(
            TaskRowDragGesture(
                isActive: isActive,
                taskID: taskID,
                onDragStart: onDragStart,
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded
            ))
    }
}

struct TaskRowDragGesture: ViewModifier {
    let isActive: Bool
    let taskID: UUID
    let onDragStart: () -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void

    func body(content: Content) -> some View {
        content
            .gesture(
                LongPressDragGesture(
                    isActive: isActive,
                    onDragStart: onDragStart,
                    onDragChanged: onDragChanged,
                    onDragEnded: onDragEnded
                )
            )
    }
}

// MARK: - UIKit Long Press + Drag via UIGestureRecognizerRepresentable

/// A UILongPressGestureRecognizer bridged into SwiftUI. Fires onDragStart after the
/// minimum hold duration, then tracks finger movement via onDragChanged (window coords),
/// and calls onDragEnded when the touch ends or is cancelled.
private struct LongPressDragGesture: UIGestureRecognizerRepresentable {
    let isActive: Bool
    let onDragStart: () -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.4
        recognizer.allowableMovement = .infinity
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        recognizer.isEnabled = isActive
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UILongPressGestureRecognizer, context: Context
    ) {
        switch recognizer.state {
        case .began:
            onDragStart()
            if let window = recognizer.view?.window {
                onDragChanged(recognizer.location(in: window))
            }
        case .changed:
            if let window = recognizer.view?.window {
                onDragChanged(recognizer.location(in: window))
            }
        case .ended, .cancelled, .failed:
            onDragEnded()
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
            // Allow simultaneous recognition with the scroll view's pan gesture
            if let pan = otherGestureRecognizer as? UIPanGestureRecognizer,
               pan.view is UIScrollView {
                return true
            }
            // Prevent simultaneous recognition with the swipe UIPanGestureRecognizer
            if otherGestureRecognizer is UIPanGestureRecognizer {
                return false
            }
            return true
        }
    }
}
