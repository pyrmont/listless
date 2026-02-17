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
                            if let drag {
                                // onDragStart is idempotent (guarded in TaskListView);
                                // wait for a real drag value so the overlay has a valid
                                // position from the very first frame.
                                onDragStart()
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
