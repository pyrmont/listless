import SwiftUI
import UIKit

/// UIViewRepresentable that captures keyboard input via UIKeyCommand when
/// SwiftUI's `.focusable()` / `@FocusState` system fails to accept
/// programmatic focus (known iPadOS limitation with hardware keyboards).
/// On iPhone, where `@FocusState` works normally, `isActive` stays false
/// and the bridge remains inert.
///
/// Also serves as the first responder for menu item actions defined by
/// `buildMenu(with:)` in the app delegate. Action methods dispatch to
/// `IOSMenuCoordinator`; `validate(_:)` enables/disables items based on
/// coordinator state.
struct KeyCommandBridge: UIViewRepresentable {
    let isActive: Bool
    let onUp: () -> Void
    let onDown: () -> Void
    let onSpace: () -> Void
    let onReturn: () -> Void
    let onDelete: () -> Void
    let onHome: () -> Void
    let onEnd: () -> Void
    let onPageUp: () -> Void
    let onPageDown: () -> Void

    func makeUIView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onUp = onUp
        view.onDown = onDown
        view.onSpace = onSpace
        view.onReturn = onReturn
        view.onDelete = onDelete
        view.onHome = onHome
        view.onEnd = onEnd
        view.onPageUp = onPageUp
        view.onPageDown = onPageDown
        view.isActive = isActive
        return view
    }

    func updateUIView(_ view: KeyCaptureView, context: Context) {
        view.onUp = onUp
        view.onDown = onDown
        view.onSpace = onSpace
        view.onReturn = onReturn
        view.onDelete = onDelete
        view.onHome = onHome
        view.onEnd = onEnd
        view.onPageUp = onPageUp
        view.onPageDown = onPageDown
        view.isActive = isActive

        if isActive && !view.isFirstResponder {
            DispatchQueue.main.async { [weak view] in
                guard let view, view.isActive else { return }
                view.becomeFirstResponder()
            }
        }
    }

    final class KeyCaptureView: UIView, IOSMenuActions {
        var isActive = false
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onSpace: (() -> Void)?
        var onReturn: (() -> Void)?
        var onDelete: (() -> Void)?
        var onHome: (() -> Void)?
        var onEnd: (() -> Void)?
        var onPageUp: (() -> Void)?
        var onPageDown: (() -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        // MARK: - Plain key commands (no modifiers)

        override var keyCommands: [UIKeyCommand]? {
            guard isActive else { return nil }
            return [
                UIKeyCommand.inputUpArrow,
                UIKeyCommand.inputDownArrow,
                " ",
                "\r",
                "\u{8}",
                UIKeyCommand.inputHome,
                UIKeyCommand.inputEnd,
                UIKeyCommand.inputPageUp,
                UIKeyCommand.inputPageDown,
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
            case UIKeyCommand.inputHome:
                onHome?()
            case UIKeyCommand.inputEnd:
                onEnd?()
            case UIKeyCommand.inputPageUp:
                onPageUp?()
            case UIKeyCommand.inputPageDown:
                onPageDown?()
            default:
                break
            }
        }

        // MARK: - Menu item actions (from buildMenu via responder chain)

        @objc func handleNewItem() {
            IOSMenuCoordinator.shared.newItem?()
        }

        @objc func handleDeleteItem() {
            IOSMenuCoordinator.shared.deleteItem?()
        }

        @objc func handleMoveUp() {
            IOSMenuCoordinator.shared.moveUp?()
        }

        @objc func handleMoveDown() {
            IOSMenuCoordinator.shared.moveDown?()
        }

        @objc func handleMarkCompleted() {
            IOSMenuCoordinator.shared.markCompleted?()
        }

        // MARK: - Menu validation

        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            switch action {
            case IOSMenuSelectors.newItem:
                return isActive
            case IOSMenuSelectors.deleteItem:
                return isActive && IOSMenuCoordinator.shared.canDelete
            case IOSMenuSelectors.moveUp:
                return isActive && IOSMenuCoordinator.shared.canMoveUp
            case IOSMenuSelectors.moveDown:
                return isActive && IOSMenuCoordinator.shared.canMoveDown
            case IOSMenuSelectors.markCompleted:
                return isActive && IOSMenuCoordinator.shared.canMarkCompleted
            default:
                return super.canPerformAction(action, withSender: sender)
            }
        }

        override func validate(_ command: UICommand) {
            super.validate(command)
            if command.action == IOSMenuSelectors.markCompleted {
                command.title = IOSMenuCoordinator.shared.markCompletedTitle
            }
        }
    }
}
