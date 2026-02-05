import SwiftUI
import UniformTypeIdentifiers

extension View {
    func taskDragGesture(
        isActive: Bool,
        taskID: UUID,
        onDragStart: @escaping () -> Void
    ) -> some View {
        self.modifier(TaskRowDragGesture(
            isActive: isActive,
            taskID: taskID,
            onDragStart: onDragStart
        ))
    }
}

struct TaskRowDragGesture: ViewModifier {
    let isActive: Bool
    let taskID: UUID
    let onDragStart: () -> Void

    @State private var dragStarted = false

    func body(content: Content) -> some View {
        if isActive {
            content
                .onDrag {
                    if !dragStarted {
                        dragStarted = true
                        onDragStart()
                    }
                    return NSItemProvider(object: taskID.uuidString as NSString)
                } preview: {
                    Color.clear.frame(width: 1, height: 1)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { _ in
                            if !dragStarted {
                                dragStarted = true
                                onDragStart()
                            }
                        }
                        .onEnded { _ in
                            dragStarted = false
                        }
                )
        } else {
            content
        }
    }

}
