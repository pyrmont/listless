import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let taskID: UUID
    let isSelected: Bool
    let onToggle: (TaskItem) -> Void
    let onSubmit: (TaskItem) -> Void
    let onTitleChange: (TaskItem, String) -> Void
    let onDelete: (TaskItem) -> Void
    let onSelect: () -> Void
    @FocusState.Binding var focusedField: TaskListView.FocusField?

    @State private var title: String

    init(
        task: TaskItem,
        taskID: UUID,
        isSelected: Bool,
        focusedField: FocusState<TaskListView.FocusField?>.Binding,
        onToggle: @escaping (TaskItem) -> Void,
        onSubmit: @escaping (TaskItem) -> Void,
        onTitleChange: @escaping (TaskItem, String) -> Void,
        onDelete: @escaping (TaskItem) -> Void,
        onSelect: @escaping () -> Void
    ) {
        self.task = task
        self.taskID = taskID
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onSubmit = onSubmit
        self.onTitleChange = onTitleChange
        self.onDelete = onDelete
        self.onSelect = onSelect
        _focusedField = focusedField
        _title = State(initialValue: task.title)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)

            TextField("New task", text: $title)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($focusedField, equals: .task(taskID))
                .onSubmit {
                    onSubmit(task)
                }
                .platformTextFieldWidth(text: title, placeholder: "New task")
                .disabled(task.isCompleted)
                .strikethrough(task.isCompleted, color: .secondary)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .background(selectionBackground)
        .contextMenu {
            Button(task.isCompleted ? "Mark as Incomplete" : "Mark as Complete") {
                onToggle(task)
            }
            Divider()
            Button("Cut") {
                cutToPasteboard()
            }
            Button("Copy") {
                copyToPasteboard()
            }
            Button("Paste") {
                pasteFromPasteboard()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete(task)
            }
        }
        .onChange(of: title) {
            guard !task.isCompleted else { return }
            onTitleChange(task, title)
        }
        .onChange(of: task.title) {
            if task.title != title {
                title = task.title
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if newValue == .task(taskID) && oldValue != .task(taskID) {
                onSelect()
            }
        }
    }

    private var selectionBackground: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selectionFill)
            } else {
                Color.clear
            }
        }
    }

    private var selectionFill: Color {
        Color.accentColor.opacity(0.2)
    }

    private func cutToPasteboard() {
        copyToPasteboard()
        onDelete(task)
    }

    private func copyToPasteboard() {
        guard !title.isEmpty else { return }
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(title, forType: .string)
        #else
        UIPasteboard.general.string = title
        #endif
    }

    private func pasteFromPasteboard() {
        #if os(macOS)
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        #else
        guard let string = UIPasteboard.general.string else { return }
        #endif
        title = string
        onTitleChange(task, string)
    }
}
