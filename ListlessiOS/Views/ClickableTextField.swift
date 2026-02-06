import SwiftUI

/// iOS version - simple TextField wrapper
struct ClickableTextField: View {
    @Binding var text: String
    let isCompleted: Bool
    let onEditingChanged: (Bool) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("New task", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.body)
            .lineLimit(1...5)
            .focused($isFocused)
            .onSubmit {
                // Resign focus when Return is pressed (same as focus loss)
                isFocused = false
            }
            .disabled(isCompleted)
            .onChange(of: isFocused) { _, newValue in
                onEditingChanged(newValue)
            }
    }
}
