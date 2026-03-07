import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let index: Int
    let totalActive: Int
    let onToggle: (TaskItem) -> Void

    var body: some View {
        Button {
            onToggle(task)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(
                        task.isCompleted
                            ? .secondary
                            : cachedTaskColor(forIndex: index, total: totalActive)
                    )
                    .font(.system(size: 17))

                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(3)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(
            task.isCompleted
                ? AnyView(Color(white: 0.15)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                : AnyView(
                    ZStack(alignment: .top) {
                        Color(white: 0.15)
                        cachedTaskColor(forIndex: index, total: totalActive)
                            .frame(height: 3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                )
        )
        .buttonStyle(.plain)
    }
}
