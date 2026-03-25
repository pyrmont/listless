import SwiftUI

struct DraftRowView: View {
    let accentColor: Color
    let isSelected: Bool
    let draftID: UUID
    @Binding var title: String
    var onEditingChanged: (Bool, Bool) -> Void
    var returnKeyType: UIReturnKeyType
    var accessibilityIdentifier: String
    var focusedField: FocusState<FocusField?>.Binding

    var body: some View {
        HStack(alignment: .center, spacing: ItemRowMetrics.contentSpacing) {
            Image(systemName: "circle")
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.secondary)
                .font(.system(size: 17))

            TappableTextField(
                text: $title,
                isCompleted: false,
                isDragging: false,
                onEditingChanged: onEditingChanged,
                returnKeyType: returnKeyType,
                uiAccessibilityIdentifier: accessibilityIdentifier
            )
            .focused(focusedField, equals: .item(draftID))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, ItemRowMetrics.contentVerticalPadding)
        .padding(.trailing, ItemRowMetrics.contentHorizontalPadding)
        .padding(.leading, ItemRowMetrics.activeLeadingPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            Color.itemCard.overlay(accentColor.opacity(0.15))
        }
        .itemCard(accentColor: accentColor, isSelected: isSelected)
    }
}
