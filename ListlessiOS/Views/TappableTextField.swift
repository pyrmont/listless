import SwiftUI
import UIKit

/// UITextField that's always present, manages its own editing state.
/// Mirrors the interface of ClickableTextField (macOS) so TaskListView
/// can drive both platforms through the same focusedField binding.
struct TappableTextField: UIViewRepresentable {
    @Binding var text: String
    let isCompleted: Bool
    let onEditingChanged: (Bool, _ shouldCreateNewTask: Bool) -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.font = .systemFont(ofSize: 18)
        textField.returnKeyType = .done
        textField.autocorrectionType = .default
        textField.autocapitalizationType = .sentences
        textField.attributedPlaceholder = NSAttributedString(
            string: "Task",
            attributes: [
                .foregroundColor: UIColor.placeholderText,
                .font: UIFont.systemFont(ofSize: 18),
            ]
        )
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        // Only update content when NOT editing to avoid interfering with active input
        if !textField.isFirstResponder {
            applyStyle(to: textField, text: text, isCompleted: isCompleted)
        }
        textField.isEnabled = !isCompleted
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEditingChanged: onEditingChanged)
    }

    private func applyStyle(to textField: UITextField, text: String, isCompleted: Bool) {
        if text.isEmpty {
            textField.attributedText = NSAttributedString(string: "")
        } else {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18),
                .foregroundColor: isCompleted ? UIColor.secondaryLabel : UIColor.label,
            ]
            if isCompleted {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                attributes[.strikethroughColor] = UIColor.secondaryLabel
            }
            textField.attributedText = NSAttributedString(string: text, attributes: attributes)
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let onEditingChanged: (Bool, _ shouldCreateNewTask: Bool) -> Void
        var returnKeyPressed: Bool = false

        init(
            text: Binding<String>,
            onEditingChanged: @escaping (Bool, _ shouldCreateNewTask: Bool) -> Void
        ) {
            _text = text
            self.onEditingChanged = onEditingChanged
        }

        @objc func textChanged(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            onEditingChanged(true, false)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if returnKeyPressed {
                // onEditingChanged(false, true) already fired in textFieldShouldReturn;
                // skip the duplicate call here.
                returnKeyPressed = false
                return
            }
            onEditingChanged(false, false)
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            returnKeyPressed = true
            onEditingChanged(false, true)
            // Return false: UIKit does NOT auto-resign first responder, so the
            // keyboard stays visible while SwiftUI focuses the next field.
            return false
        }
    }
}
