import SwiftUI
import UIKit

/// UITextView that's always present, manages its own editing state, and expands
/// vertically to fit its content. Mirrors the interface of ClickableTextField (macOS)
/// so TaskListView can drive both platforms through the same focusedField binding.
struct TappableTextField: UIViewRepresentable {
    @Binding var text: String
    let isCompleted: Bool
    let onEditingChanged: (Bool, _ shouldCreateNewTask: Bool) -> Void
    var onContentChange: ((String) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = TaskRowMetrics.bodyUIK
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.returnKeyType = .done

        let placeholder = UILabel()
        placeholder.text = "Enter task"
        placeholder.font = TaskRowMetrics.bodyUIK
        placeholder.textColor = .placeholderText
        placeholder.tag = 100
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholder.topAnchor.constraint(equalTo: textView.topAnchor),
        ])

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if !textView.isFirstResponder {
            applyStyle(to: textView, text: text, isCompleted: isCompleted)
        }
        textView.isEditable = !isCompleted
        textView.isSelectable = !isCompleted
        if let placeholder = textView.viewWithTag(100) as? UILabel {
            placeholder.isHidden = !text.isEmpty
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let proposedWidth = proposal.width ?? uiView.bounds.width
        let width = proposedWidth > 0 ? proposedWidth : (uiView.window?.bounds.width ?? 0)
        guard width > 0 else { return nil }
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEditingChanged: onEditingChanged, onContentChange: onContentChange)
    }

    private func applyStyle(to textView: UITextView, text: String, isCompleted: Bool) {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: TaskRowMetrics.bodyUIK,
            .foregroundColor: isCompleted ? UIColor.secondaryLabel : UIColor.label,
        ]
        if isCompleted {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = UIColor.secondaryLabel
        }
        textView.attributedText = NSAttributedString(string: text, attributes: attributes)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let onEditingChanged: (Bool, _ shouldCreateNewTask: Bool) -> Void
        let onContentChange: ((String) -> Void)?
        var returnKeyPressed: Bool = false

        init(
            text: Binding<String>,
            onEditingChanged: @escaping (Bool, _ shouldCreateNewTask: Bool) -> Void,
            onContentChange: ((String) -> Void)? = nil
        ) {
            _text = text
            self.onEditingChanged = onEditingChanged
            self.onContentChange = onContentChange
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            onContentChange?(textView.text)
            if let placeholder = textView.viewWithTag(100) as? UILabel {
                placeholder.isHidden = !textView.text.isEmpty
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            onEditingChanged(true, false)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if returnKeyPressed {
                returnKeyPressed = false
                return
            }
            onEditingChanged(false, false)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard text == "\n" else { return true }
            // Intercept Return: trigger new-task creation without inserting a newline.
            // Return false keeps the text view as first responder, matching the UITextField
            // behaviour where textFieldShouldReturn returned false — SwiftUI then
            // transfers first responder atomically in the same render pass.
            returnKeyPressed = true
            onEditingChanged(false, true)
            return false
        }
    }
}
