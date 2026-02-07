import SwiftUI

/// iOS version - simple TextField wrapper
struct ClickableTextField: View {
    @Binding var text: String
    let isCompleted: Bool
    let onEditingChanged: (Bool, _ shouldCreateNewTask: Bool) -> Void

    @FocusState private var isFocused: Bool
    @State private var submittedViaReturn = false

    var body: some View {
        TextField("New task", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.body)
            .lineLimit(1...5)
            .focused($isFocused)
            .onSubmit {
                // Return key pressed - mark for new task creation
                submittedViaReturn = true
                isFocused = false
            }
            .disabled(isCompleted)
            .onChange(of: isFocused) { _, newValue in
                if newValue {
                    // Focus gained
                    onEditingChanged(true, false)
                } else {
                    // Focus lost - check if it was via Return key
                    onEditingChanged(false, submittedViaReturn)
                    submittedViaReturn = false
                }
            }
    }
}
