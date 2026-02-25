import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension View {
    func taskDragGesture(
        isActive: Bool,
        taskID: UUID,
        onDragStart: @escaping () -> Void,
        onLift: @escaping () -> Void = {},
        onLiftEnd: @escaping () -> Void = {}
    ) -> some View {
        self.modifier(
            TaskRowDragGesture(
                isActive: isActive,
                taskID: taskID,
                onDragStart: onDragStart,
                onLift: onLift,
                onLiftEnd: onLiftEnd
            ))
    }
}

struct TaskRowDragGesture: ViewModifier {
    let isActive: Bool
    let taskID: UUID
    let onDragStart: () -> Void
    let onLift: () -> Void
    let onLiftEnd: () -> Void

    @State private var dragStarted = false
    @State private var mouseUpMonitor: Any?

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
                    LongPressGesture(minimumDuration: 0.4)
                        .onEnded { _ in
                            dragStarted = false
                            onLift()
                            installMouseUpMonitor()
                        }
                )
        } else {
            content
        }
    }

    private func installMouseUpMonitor() {
        removeMouseUpMonitor()
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
            removeMouseUpMonitor()
            dragStarted = false
            onLiftEnd()
            return event
        }
    }

    private func removeMouseUpMonitor() {
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            mouseUpMonitor = nil
        }
    }
}
