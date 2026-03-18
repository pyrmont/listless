import SwiftUI

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
        if #available(iOS 18, *) {
            content
                .gesture(
                    SimultaneousDragGesture(
                        isActive: isActive,
                        onDragStart: onDragStart,
                        onDragChanged: onDragChanged,
                        onDragEnded: onDragEnded
                    )
                )
        } else {
            content
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                        .onChanged { value in
                            switch value {
                            case .second(true, let drag):
                                onDragStart()
                                if let drag {
                                    onDragChanged(drag.location)
                                }
                            default:
                                break
                            }
                        }
                        .onEnded { _ in
                            onDragEnded()
                        },
                    including: isActive ? .all : .none
                )
        }
    }
}

// MARK: - iOS 26 workaround

/// Uses UILongPressGestureRecognizer (minimumPressDuration: 0.4) via
/// UIGestureRecognizerRepresentable to avoid iOS 26's child-gesture-blocks-
/// ancestor issue. The delegate returns shouldRecognizeSimultaneouslyWith:true
/// so the ScrollView's pan gesture is preserved.
@available(iOS 18.0, *)
private struct SimultaneousDragGesture: UIGestureRecognizerRepresentable {
    let isActive: Bool
    let onDragStart: () -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.4
        recognizer.delegate = context.coordinator
        recognizer.isEnabled = isActive
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
            // Long press completed — fire drag start immediately so the row
            // lifts visually before any finger movement.
            onDragStart()

        case .changed:
            let location = recognizer.location(in: recognizer.view?.window)
            onDragChanged(location)

        case .ended, .cancelled:
            onDragEnded()

        default:
            break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
