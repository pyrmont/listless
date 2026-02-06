import SwiftUI
import AppKit

/// Custom NSTextField that notifies when clicked (becomes first responder)
class ClickableNSTextField: NSTextField {
    var onBecomeFirstResponder: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            onBecomeFirstResponder?()
        }
        return result
    }
}

/// NSTextField that's always present, manages its own editing state
struct ClickableTextField: NSViewRepresentable {
    @Binding var text: String
    let isCompleted: Bool
    let onEditingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> ClickableNSTextField {
        let textField = ClickableNSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.lineBreakMode = .byWordWrapping
        textField.maximumNumberOfLines = 5
        textField.usesSingleLineMode = false
        textField.cell?.wraps = true
        textField.cell?.isScrollable = false
        textField.isSelectable = true  // Shows I-beam cursor on hover
        textField.isEditable = true    // Always editable, becomes first responder on click

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
        }

        // Disable if completed
        textField.isEditable = !isCompleted
        textField.isSelectable = !isCompleted
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ClickableNSTextField, context: Context) -> CGSize? {
        let maxWidth = proposal.width ?? 300
        let isEditing = nsView.currentEditor() != nil

        if isEditing {
            // When editing, take full width
            let height = calculateHeight(for: text, width: maxWidth, font: nsView.font ?? .systemFont(ofSize: NSFont.systemFontSize))
            return CGSize(width: maxWidth, height: max(height, 22))
        } else {
            // When not editing, size to content
            let width = calculateWidth(for: text, font: nsView.font ?? .systemFont(ofSize: NSFont.systemFontSize))
            let height = calculateHeight(for: text, width: width, font: nsView.font ?? .systemFont(ofSize: NSFont.systemFontSize))
            return CGSize(width: min(width, maxWidth), height: max(height, 22))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEditingChanged: onEditingChanged)
    }

    // Calculate text width
    private func calculateWidth(for text: String, font: NSFont) -> CGFloat {
        let attributedString = NSAttributedString(
            string: text.isEmpty ? "New task" : text,
            attributes: [.font: font]
        )
        let size = attributedString.size()
        return ceil(size.width) + 4
    }

    // Calculate text height with wrapping
    private func calculateHeight(for text: String, width: CGFloat, font: NSFont) -> CGFloat {
        let attributedString = NSAttributedString(
            string: text.isEmpty ? "New task" : text,
            attributes: [.font: font]
        )
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)

        return ceil(rect.height) + 4
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        let onEditingChanged: (Bool) -> Void

        init(text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void) {
            _text = text
            self.onEditingChanged = onEditingChanged
        }

        @MainActor
        func applyStyle(to textField: NSTextField, text: String, isCompleted: Bool) {
            let displayText = text.isEmpty ? "New task" : text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: text.isEmpty ? NSColor.secondaryLabelColor : (isCompleted ? NSColor.secondaryLabelColor : NSColor.labelColor),
                .strikethroughStyle: isCompleted ? NSUnderlineStyle.single.rawValue : 0,
                .strikethroughColor: NSColor.secondaryLabelColor
            ]
            textField.attributedStringValue = NSAttributedString(string: displayText, attributes: attributes)
        }

        func handleBecomeFirstResponder() {
            print("🟡 ClickableTextField.becomeFirstResponder - calling onEditingChanged(true)")
            onEditingChanged(true)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            print("🟡 ClickableTextField.controlTextDidEndEditing fired")
            onEditingChanged(false)
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            text = textField.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Resign first responder, which triggers controlTextDidEndEditing → onEditingChanged(false)
                control.window?.makeFirstResponder(nil)
                return true  // Prevent newline insertion
            }
            return false
        }
    }
}
