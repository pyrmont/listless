import SwiftUI

extension View {
    func taskTapGesture(
        onCheckboxTap: @escaping () -> Void,
        onTextTap: @escaping () -> Void
    ) -> some View {
        self.modifier(
            TaskRowTapGesture(
                onCheckboxTap: onCheckboxTap,
                onTextTap: onTextTap
            ))
    }
}

struct TaskRowTapGesture: ViewModifier {
    let onCheckboxTap: () -> Void
    let onTextTap: () -> Void

    private let checkboxZoneWidth: CGFloat = 48  // Checkbox + padding area

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                handleTap(at: location)
            }
    }

    private func handleTap(at location: CGPoint) {
        if location.x <= checkboxZoneWidth {
            // Tap in checkbox zone
            onCheckboxTap()
        } else {
            // Tap in text zone - TextField will handle focus natively
            onTextTap()
        }
    }
}
