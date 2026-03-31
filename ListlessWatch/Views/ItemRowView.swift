import SwiftUI

struct ItemRowView: View {
    let item: ItemValue
    let index: Int
    let totalActive: Int
    let colorTheme: ColorTheme
    let onToggle: (ItemValue) -> Void

    var body: some View {
        Button {
            onToggle(item)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(
                        item.isCompleted
                            ? .secondary
                            : cachedItemColor(forIndex: index, total: totalActive, theme: colorTheme)
                    )
                    .font(.system(size: 17))

                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .lineLimit(3)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(
            item.isCompleted
                ? AnyView(Color(white: 0.15)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                : AnyView(
                    ZStack(alignment: .top) {
                        Color(white: 0.15)
                        cachedItemColor(forIndex: index, total: totalActive, theme: colorTheme)
                            .frame(height: 3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                )
        )
        .buttonStyle(.plain)
    }
}
