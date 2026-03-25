import SwiftUI

extension View {
    func itemDragGesture(
        isActive: Bool,
        itemID: UUID,
        onDragStart: @escaping (CGFloat) -> Void,
        onDragChanged: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping () -> Void
    ) -> some View {
        self.modifier(
            ItemRowDragGesture(
                isActive: isActive,
                itemID: itemID,
                onDragStart: onDragStart,
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded
            ))
    }
}

struct ItemRowDragGesture: ViewModifier {
    let isActive: Bool
    let itemID: UUID
    let onDragStart: (CGFloat) -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void

    func body(content: Content) -> some View {
        content
            .gesture(
                SimultaneousDragGesture(
                    isActive: isActive,
                    onDragStart: onDragStart,
                    onDragChanged: onDragChanged,
                    onDragEnded: onDragEnded
                )
            )
    }
}

// MARK: - iOS 26 workaround

/// Uses UILongPressGestureRecognizer (minimumPressDuration: 0.4) via
/// UIGestureRecognizerRepresentable to avoid iOS 26's child-gesture-blocks-
/// ancestor issue. The delegate returns shouldRecognizeSimultaneouslyWith:true
/// so the ScrollView's pan gesture is preserved.
private struct SimultaneousDragGesture: UIGestureRecognizerRepresentable {
    let isActive: Bool
    let onDragStart: (CGFloat) -> Void
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
            let width = recognizer.view?.bounds.width ?? 0
            onDragStart(width)

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

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer.view is UITextView
        }
    }
}
