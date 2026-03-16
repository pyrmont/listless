import AppKit
import SwiftUI

/// Custom NSTextField that notifies when clicked (becomes first responder)
class ClickableNSTextField: NSTextField {
    var onBecomeFirstResponder: (() -> Void)?

    /// The task ID this text field represents, used by the per-window
    /// `WindowCoordinator.allowedFocusTarget` check.
    var taskID: UUID?

    override var acceptsFirstResponder: Bool {
        // Always allow if this field is already editing.
        if currentEditor() != nil { return super.acceptsFirstResponder }

        // Always allow click-initiated focus.
        if let event = NSApp.currentEvent, event.type == .leftMouseDown {
            return super.acceptsFirstResponder
        }

        // Check the per-window coordinator for an allowed focus target.
        if let window,
            let delegate = NSApp.delegate as? AppDelegate,
            let coordinator = delegate.coordinator(for: window)
        {
            if let allowed = coordinator.allowedFocusTarget {
                // A specific target is set — only that field may accept.
                guard let taskID, case .task(let allowedID) = allowed, allowedID == taskID else {
                    return false
                }
            }
        }

        return super.acceptsFirstResponder
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window,
            let taskID,
            let delegate = NSApp.delegate as? AppDelegate,
            let coordinator = delegate.coordinator(for: window)
        else { return }
        if case .task(let allowedID) = coordinator.allowedFocusTarget, allowedID == taskID {
            coordinator.allowedFocusTarget = nil
            window.makeFirstResponder(self)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result, let event = NSApp.currentEvent, event.type == .leftMouseDown {
            let locationInView = convert(event.locationInWindow, from: nil)
            if bounds.contains(locationInView) {
                onBecomeFirstResponder?()
            }
        }
        return result
    }
}

/// NSTextField that's always present, manages its own editing state
struct ClickableTextField: NSViewRepresentable {
    @Binding var text: String
    let isCompleted: Bool
    let onEditingChanged: (Bool, _ shouldCreateNewTask: Bool) -> Void
    var taskID: UUID? = nil
    var onContentChange: ((String) -> Void)? = nil

    func makeNSView(context: Context) -> ClickableNSTextField {
        let textField = ClickableNSTextField()
        textField.taskID = taskID
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.placeholderString = "Enter text"
        textField.lineBreakMode = .byWordWrapping
        textField.maximumNumberOfLines = 5
        textField.usesSingleLineMode = false
        textField.cell?.wraps = true
        textField.cell?.isScrollable = false
        textField.isSelectable = true  // Shows I-beam cursor on hover
        textField.isEditable = true  // Always editable, becomes first responder on click

        // Notify when field is clicked (becomes first responder)
        textField.onBecomeFirstResponder = {
            context.coordinator.handleBecomeFirstResponder()
        }

        return textField
    }

    func updateNSView(_ textField: ClickableNSTextField, context: Context) {
        let hasEditor = textField.currentEditor() != nil

        // Only update content when NOT editing to avoid interfering with field editor
        if !hasEditor {
            // Update text if different
            if textField.stringValue != text {
                textField.stringValue = text
            }

            // Apply styling (sets attributedStringValue)
            context.coordinator.applyStyle(to: textField, text: text, isCompleted: isCompleted)
        } else if text.isEmpty && !textField.stringValue.isEmpty {
            // External reset (e.g. phantom row chaining) — clear the field
            // even though the field editor is active.
            textField.stringValue = ""
        }

        // Disable if completed
        textField.isEditable = !isCompleted
        textField.isSelectable = !isCompleted
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ClickableNSTextField, context: Context)
        -> CGSize?
    {
        let maxWidth = proposal.width ?? 300
        let isEditing = nsView.currentEditor() != nil

        // Always calculate height based on maxWidth to preserve multiline wrapping
        let height = calculateHeight(
            for: text, width: maxWidth,
            font: nsView.font ?? .systemFont(ofSize: NSFont.systemFontSize))

        if isEditing {
            // When editing, take full width
            return CGSize(width: maxWidth, height: max(height, 22))
        } else {
            // When not editing, size width to content but maintain multiline height
            let width = calculateWidth(
                for: text, font: nsView.font ?? .systemFont(ofSize: NSFont.systemFontSize))
            return CGSize(width: min(width, maxWidth), height: max(height, 22))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEditingChanged: onEditingChanged, onContentChange: onContentChange)
    }

    enum EditEndReason {
        case returnKey
        case escape
        case focusLost
    }

    // Calculate text width
    private func calculateWidth(for text: String, font: NSFont) -> CGFloat {
        let attributedString = NSAttributedString(
            string: text.isEmpty ? "Enter text" : text,
            attributes: [.font: font]
        )
        let size = attributedString.size()
        return ceil(size.width) + 4
    }

    // Calculate text height with wrapping
    private func calculateHeight(for text: String, width: CGFloat, font: NSFont) -> CGFloat {
        let displayText = text.isEmpty ? "Enter text" : text
        let rect = (displayText as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return ceil(rect.height) + 4
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        let onEditingChanged: (Bool, _ shouldCreateNewTask: Bool) -> Void
        let onContentChange: ((String) -> Void)?
        var editEndReason: EditEndReason = .focusLost

        init(
            text: Binding<String>,
            onEditingChanged: @escaping (Bool, _ shouldCreateNewTask: Bool) -> Void,
            onContentChange: ((String) -> Void)? = nil
        ) {
            _text = text
            self.onEditingChanged = onEditingChanged
            self.onContentChange = onContentChange
        }

        func applyStyle(to textField: NSTextField, text: String, isCompleted: Bool) {
            guard !text.isEmpty else {
                textField.stringValue = ""
                return
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: isCompleted ? NSColor.secondaryLabelColor : NSColor.labelColor,
                .strikethroughStyle: isCompleted ? NSUnderlineStyle.single.rawValue : 0,
                .strikethroughColor: NSColor.secondaryLabelColor,
            ]
            textField.attributedStringValue = NSAttributedString(
                string: text, attributes: attributes)
        }

        private var hasNotifiedEditingStarted = false

        func handleBecomeFirstResponder() {
            hasNotifiedEditingStarted = true
            onEditingChanged(true, false)
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            guard !hasNotifiedEditingStarted else { return }
            hasNotifiedEditingStarted = true
            onEditingChanged(true, false)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            hasNotifiedEditingStarted = false
            let shouldCreateNewTask = editEndReason == .returnKey
            editEndReason = .focusLost  // Reset for next time
            onEditingChanged(false, shouldCreateNewTask)
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            text = textField.stringValue
            onContentChange?(textField.stringValue)
        }

        func control(
            _ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector
        )
            -> Bool
        {
            // Note: makeFirstResponder(nil) can trigger a Thread Performance
            // Checker priority inversion warning. This is internal to AppKit's
            // first responder machinery, not caused by our callback chain.
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Return key pressed — set the per-window allowed focus
                // target to .scrollView so no text field can steal focus
                // during reconciliation. Cleared in TaskListView's outer
                // onChange(of: focusedFieldBinding).
                editEndReason = .returnKey
                setAllowedFocusTarget(for: control.window, target: .scrollView)
                control.window?.makeFirstResponder(nil)
                return true  // Prevent newline insertion
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Escape key pressed — same strategy as Return.
                editEndReason = .escape
                setAllowedFocusTarget(for: control.window, target: .scrollView)
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }

        private func setAllowedFocusTarget(for window: NSWindow?, target: FocusField) {
            guard let window,
                let delegate = NSApp.delegate as? AppDelegate,
                let coordinator = delegate.coordinator(for: window)
            else { return }
            coordinator.allowedFocusTarget = target
        }
    }
}
