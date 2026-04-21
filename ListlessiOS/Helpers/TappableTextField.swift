import SwiftUI
import UIKit

/// UITextView that's always present, manages its own editing state, and expands
/// vertically to fit its content. Mirrors the interface of ClickableTextField (macOS)
/// so ItemListView can drive both platforms through the same focusedField binding.
struct TappableTextField: UIViewRepresentable {
    @Binding var text: String
    let isCompleted: Bool
    let isDragging: Bool
    let onEditingChanged: (Bool, _ shouldCreateNewItem: Bool) -> Void
    var returnKeyType: UIReturnKeyType = .done
    var onContentChange: ((String) -> Void)? = nil
    var uiAccessibilityIdentifier: String? = nil
    var initialCursorPoint: CGPoint? = nil

    func makeUIView(context: Context) -> UITextView {
        PerfSampler.shared.measure("TappableTextField.makeUIView") {
            let textView = UITextView()
            textView.accessibilityIdentifier = uiAccessibilityIdentifier
            textView.delegate = context.coordinator
            textView.font = ItemRowMetrics.bodyUIK
            textView.backgroundColor = .clear
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.isScrollEnabled = false
            textView.autocorrectionType = .default
            textView.autocapitalizationType = .sentences
            textView.returnKeyType = returnKeyType

            let placeholder = UILabel()
            placeholder.text = "Enter text"
            placeholder.font = ItemRowMetrics.bodyUIK
            placeholder.textColor = .placeholderText
            placeholder.tag = 100
            placeholder.translatesAutoresizingMaskIntoConstraints = false
            textView.addSubview(placeholder)
            NSLayoutConstraint.activate([
                placeholder.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
                placeholder.topAnchor.constraint(equalTo: textView.topAnchor),
            ])

            context.coordinator.textView = textView
            return textView
        }
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        PerfSampler.shared.measure("TappableTextField.updateUIView") {
            updateUIViewBody(textView, context: context)
        }
    }

    private func updateUIViewBody(_ textView: UITextView, context: Context) {
        if !textView.isFirstResponder {
            applyStyle(to: textView, text: text, isCompleted: isCompleted)
        } else if text.isEmpty && !textView.text.isEmpty {
            // External reset (e.g. phantom row chaining) — clear the view
            // even though it's first responder.
            textView.text = ""
            if let placeholder = textView.viewWithTag(100) as? UILabel {
                placeholder.isHidden = false
            }
        }
        if textView.returnKeyType != returnKeyType {
            textView.returnKeyType = returnKeyType
            textView.reloadInputViews()
        }
        textView.accessibilityIdentifier = uiAccessibilityIdentifier
        textView.isEditable = !isCompleted
        textView.isSelectable = !isCompleted
        textView.isUserInteractionEnabled = !isCompleted
        // Defer isDragging updates to break an AttributeGraph cycle: setting
        // isEditable/isSelectable during updateUIView causes UITextView to
        // invalidate its intrinsic content size, creating a layout-to-state
        // backward edge that SwiftUI's dependency graph flags as a cycle.
        // Deferring moves the UIView mutation outside of the evaluation pass.
        let dragging = isDragging
        if dragging != context.coordinator.isDragging {
            let coordinator = context.coordinator
            // Task (not DispatchQueue.main.async) since coordinator is Sendable.
            Task { @MainActor in
                coordinator.setDragging(dragging)
            }
        }
        if let placeholder = textView.viewWithTag(100) as? UILabel {
            placeholder.isHidden = !text.isEmpty
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        PerfSampler.shared.measure("TappableTextField.sizeThatFits") {
            let proposedWidth = proposal.width ?? uiView.bounds.width
            let width = proposedWidth > 0 ? proposedWidth : (uiView.window?.bounds.width ?? 0)
            guard width > 0 else { return nil }
            let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            return CGSize(width: width, height: fitted.height)
        }
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(text: $text, onEditingChanged: onEditingChanged, onContentChange: onContentChange)
        coordinator.initialCursorPoint = initialCursorPoint
        return coordinator
    }

    private func applyStyle(to textView: UITextView, text: String, isCompleted: Bool) {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: ItemRowMetrics.bodyUIK,
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
        let onEditingChanged: (Bool, _ shouldCreateNewItem: Bool) -> Void
        let onContentChange: ((String) -> Void)?
        var returnKeyPressed: Bool = false
        weak var textView: UITextView?
        private(set) var isDragging = false
        var initialCursorPoint: CGPoint?

        init(
            text: Binding<String>,
            onEditingChanged: @escaping (Bool, _ shouldCreateNewItem: Bool) -> Void,
            onContentChange: ((String) -> Void)? = nil
        ) {
            _text = text
            self.onEditingChanged = onEditingChanged
            self.onContentChange = onContentChange
        }

        func setDragging(_ dragging: Bool) {
            guard dragging != isDragging else { return }
            isDragging = dragging
            guard let textView else { return }
            if dragging {
                textView.isEditable = false
                textView.isSelectable = false
            } else {
                // Restore based on current completion state — updateUIView
                // will also set these on the next SwiftUI evaluation pass.
                textView.isEditable = true
                textView.isSelectable = true
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            onContentChange?(textView.text)
            if let placeholder = textView.viewWithTag(100) as? UILabel {
                placeholder.isHidden = !textView.text.isEmpty
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            PerfSampler.shared.record(
                label: "TappableTextField.didBeginEditing",
                durationMs: 0
            )
            if let point = initialCursorPoint {
                initialCursorPoint = nil
                textView.layoutIfNeeded()
                if let position = textView.closestPosition(to: point) {
                    textView.selectedTextRange = textView.textRange(from: position, to: position)
                }
            }
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
            // Intercept Return: trigger new-item creation without inserting a newline.
            returnKeyPressed = true
            onEditingChanged(false, true)
            if textView.returnKeyType == .done {
                // Non-last item (or empty title): resign immediately so SwiftUI's
                // focus binding update reliably clears the field on iPad, where the
                // deferred focusedFieldBinding = .scrollView alone doesn't resign
                // the UITextView through the hardware-keyboard focus system.
                textView.resignFirstResponder()
            }
            // Return false: for .next (last active item with text), the text view
            // stays first responder so SwiftUI can transfer focus atomically to the
            // newly created item's text field in the same render pass.
            return false
        }
    }
}
