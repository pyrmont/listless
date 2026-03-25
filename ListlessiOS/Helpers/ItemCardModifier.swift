import SwiftUI

struct ItemCardModifier: ViewModifier {
    var accentColor: Color
    var isSelected: Bool

    static let shape = UnevenRoundedRectangle(
        topLeadingRadius: 0, bottomLeadingRadius: 0,
        bottomTrailingRadius: ItemRowMetrics.trailingCornerRadius,
        topTrailingRadius: ItemRowMetrics.trailingCornerRadius
    )

    func body(content: Content) -> some View {
        content
            .clipShape(Self.shape)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: ItemRowMetrics.accentBarWidth)
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
    func itemCard(accentColor: Color, isSelected: Bool) -> some View {
        modifier(ItemCardModifier(accentColor: accentColor, isSelected: isSelected))
    }
}
