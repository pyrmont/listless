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
        content
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag):
                            // Fire onDragStart as soon as the long press completes so the
                            // row lifts visually before any finger movement. onDragStart is
                            // idempotent (guarded in TaskListView).
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
