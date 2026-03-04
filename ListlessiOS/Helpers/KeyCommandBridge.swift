import SwiftUI
import UIKit

/// UIViewRepresentable that captures keyboard input via UIKeyCommand when
/// SwiftUI's `.focusable()` / `@FocusState` system fails to accept
/// programmatic focus (known iPadOS limitation with hardware keyboards).
/// On iPhone, where `@FocusState` works normally, `isActive` stays false
/// and the bridge remains inert.
struct KeyCommandBridge: UIViewRepresentable {
    let isActive: Bool
    let onUp: () -> Void
    let onDown: () -> Void
    let onSpace: () -> Void
    let onReturn: () -> Void
    let onDelete: () -> Void

    func makeUIView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onUp = onUp
        view.onDown = onDown
        view.onSpace = onSpace
        view.onReturn = onReturn
        view.onDelete = onDelete
        view.isActive = isActive
        return view
    }

    func updateUIView(_ view: KeyCaptureView, context: Context) {
        view.onUp = onUp
        view.onDown = onDown
        view.onSpace = onSpace
        view.onReturn = onReturn
        view.onDelete = onDelete
        view.isActive = isActive

        if isActive && !view.isFirstResponder {
            DispatchQueue.main.async { [weak view] in
                guard let view, view.isActive else { return }
                view.becomeFirstResponder()
            }
        }
    }

    final class KeyCaptureView: UIView {
        var isActive = false
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onSpace: (() -> Void)?
        var onReturn: (() -> Void)?
        var onDelete: (() -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override var keyCommands: [UIKeyCommand]? {
            guard isActive else { return nil }
            return [
                UIKeyCommand.inputUpArrow,
                UIKeyCommand.inputDownArrow,
                " ",
                "\r",
                "\u{8}",
            ].map { input in
                let cmd = UIKeyCommand(
                    input: input,
                    modifierFlags: [],
                    action: #selector(handleKeyCommand(_:))
                )
                cmd.wantsPriorityOverSystemBehavior = true
                return cmd
            }
        }

        @objc private func handleKeyCommand(_ sender: UIKeyCommand) {
            switch sender.input {
            case UIKeyCommand.inputUpArrow:
                onUp?()
            case UIKeyCommand.inputDownArrow:
                onDown?()
            case " ":
                onSpace?()
            case "\r":
                onReturn?()
            case "\u{8}":
                onDelete?()
            default:
                break
            }
        }
    }
}
