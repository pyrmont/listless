import AppKit
import SwiftUI

/// Monitors for mouse clicks in empty scroll view space (below content).
///
/// SwiftUI's `.contentShape(Rectangle()).onTapGesture` on a `ScrollView`
/// does not reliably fire for clicks in the area below the document view
/// on macOS, because `NSScrollView`'s clip view handles the event before
/// SwiftUI's gesture system. This representable installs a local event
/// monitor that detects those clicks and forwards them to a handler.
struct BackgroundClickMonitor: NSViewRepresentable {
    let onClick: () -> Void

    func makeNSView(context: Context) -> ClickMonitorNSView {
        let view = ClickMonitorNSView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: ClickMonitorNSView, context: Context) {
        nsView.onClick = onClick
    }
}

final class ClickMonitorNSView: NSView {
    var onClick: (() -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installMonitor()
        } else {
            removeMonitor()
        }
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) {
            [weak self] event in
            self?.handleClick(event)
            return event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handleClick(_ event: NSEvent) {
        guard let window, event.window == window else { return }

        let pointInSelf = convert(event.locationInWindow, from: nil)
        guard bounds.contains(pointInSelf) else { return }

        guard let hitView = window.contentView?.hitTest(event.locationInWindow)
        else { return }

        if hitView is NSClipView {
            onClick?()
        }
    }

}
