import SwiftUI

struct TaskCardModifier: ViewModifier {
    var accentColor: Color
    var isSelected: Bool

    static let shape = UnevenRoundedRectangle(
        topLeadingRadius: 0, bottomLeadingRadius: 0,
        bottomTrailingRadius: TaskRowMetrics.trailingCornerRadius,
        topTrailingRadius: TaskRowMetrics.trailingCornerRadius
    )

    func body(content: Content) -> some View {
        content
            .clipShape(Self.shape)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: TaskRowMetrics.accentBarWidth)
            }
            .overlay(
                isSelected
                    ? Self.shape
                        .strokeBorder(accentColor.opacity(0.40), lineWidth: 2)
                    : nil
            )
    }
}

extension View {
    func taskCard(accentColor: Color, isSelected: Bool) -> some View {
        modifier(TaskCardModifier(accentColor: accentColor, isSelected: isSelected))
    }
}
