import SwiftUI

struct ItemRowView: View {
    let item: ItemEntity
    let index: Int
    let totalActive: Int
    let onToggle: (ItemEntity) -> Void

    var body: some View {
        Button {
            onToggle(item)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(
                        item.isCompleted
                            ? .secondary
                            : cachedItemColor(forIndex: index, total: totalActive)
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
                        cachedItemColor(forIndex: index, total: totalActive)
                            .frame(height: 3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                )
        )
        .buttonStyle(.plain)
    }
}
