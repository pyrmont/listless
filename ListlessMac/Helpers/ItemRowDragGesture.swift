import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension View {
    func itemDragGesture(
        isActive: Bool,
        itemID: UUID,
        onDragStart: @escaping () -> Void,
        onLift: @escaping () -> Void = {},
        onLiftEnd: @escaping () -> Void = {}
    ) -> some View {
        self.modifier(
            ItemRowDragGesture(
                isActive: isActive,
                itemID: itemID,
                onDragStart: onDragStart,
                onLift: onLift,
                onLiftEnd: onLiftEnd
            ))
    }
}

struct ItemRowDragGesture: ViewModifier {
    let isActive: Bool
    let itemID: UUID
    let onDragStart: () -> Void
    let onLift: () -> Void
    let onLiftEnd: () -> Void

    @State private var isLifted = false
    @State private var dragSource = DragSourceManager()
    @State private var monitors: [Any] = []

    func body(content: Content) -> some View {
        if isActive {
            content
                .background { DragSourceAnchor(manager: dragSource) }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .onEnded { _ in
                            isLifted = true
                            onLift()
                            installMonitors()
                        }
                )
        } else {
            content
        }
    }

    private func installMonitors() {
        removeMonitors()

        dragSource.onDragEnd = {
            endLift()
        }

        // Mouse dragged: begin drag session
        monitors.append(
            NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { event in
                if isLifted && !dragSource.isActive {
                    onDragStart()
                    dragSource.beginDrag(itemID: itemID, event: event)
                }
                return event
            }!
        )

        // Mouse up: end lift if no drag session started
        monitors.append(
            NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
                if isLifted && !dragSource.isActive {
                    endLift()
                }
                return event
            }!
        )

        // Escape: cancel lift (during a drag session, AppKit handles
        // Escape internally and calls draggingSession(_:endedAt:operation:))
        monitors.append(
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 && isLifted && !dragSource.isActive {
                    endLift()
                    return nil
                }
                return event
            }!
        )
    }

    private func endLift() {
        removeMonitors()
        isLifted = false
        dragSource.isActive = false
        onLiftEnd()
    }

    private func removeMonitors() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors = []
    }
}

// MARK: - Drag Source

@MainActor
class DragSourceManager: NSObject, NSDraggingSource {
    weak var sourceView: NSView?
    var isActive = false
    var onDragEnd: (() -> Void)?

    func beginDrag(itemID: UUID, event: NSEvent) {
        guard let sourceView, !isActive else { return }
        let item = NSDraggingItem(pasteboardWriter: itemID.uuidString as NSString)
        let image = NSImage(size: NSSize(width: 1, height: 1))
        item.setDraggingFrame(sourceView.bounds, contents: image)
        isActive = true
        sourceView.beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        isActive = false
        onDragEnd?()
    }
}

// MARK: - Drag Source Anchor View

private class DragPassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct DragSourceAnchor: NSViewRepresentable {
    let manager: DragSourceManager

    func makeNSView(context: Context) -> NSView {
        let view = DragPassthroughView()
        manager.sourceView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        manager.sourceView = nsView
    }
}
