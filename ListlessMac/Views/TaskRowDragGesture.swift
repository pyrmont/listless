import SwiftUI
import UniformTypeIdentifiers

extension View {
    func taskDragGesture(
        isActive: Bool,
        taskID: UUID,
        taskTitle: String,
        onDragStart: @escaping () -> Void,
        onDragEnd: @escaping () -> Void,
        onDrop: @escaping (UUID) -> Void
    ) -> some View {
        self.modifier(TaskRowDragGesture(
            isActive: isActive,
            taskID: taskID,
            taskTitle: taskTitle,
            onDragStart: onDragStart,
            onDragEnd: onDragEnd,
            onDrop: onDrop
        ))
    }
}

struct TaskRowDragGesture: ViewModifier {
    let isActive: Bool
    let taskID: UUID
    let taskTitle: String
    let onDragStart: () -> Void
    let onDragEnd: () -> Void
    let onDrop: (UUID) -> Void

    func body(content: Content) -> some View {
        if isActive {
            content
                .onDrag {
                    onDragStart()
                    return NSItemProvider(object: taskID.uuidString as NSString)
                } preview: {
                    dragPreview
                }
                .dropDestination(for: String.self) { items, location in
                    guard let droppedUUIDString = items.first,
                          let droppedUUID = UUID(uuidString: droppedUUIDString) else {
                        return false
                    }
                    DispatchQueue.main.async {
                        onDrop(droppedUUID)
                        onDragEnd()
                    }
                    return true
                }
        } else {
            content
        }
    }

    private var dragPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .frame(width: 20, height: 20)
            Text(taskTitle.isEmpty ? "New task" : taskTitle)
                .font(.body)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}
