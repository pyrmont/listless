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
                    .foregroundStyle(
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
        }
        .buttonStyle(.plain)
    }
}
