import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let taskID: UUID
    let isSelected: Bool
    let isEditing: Bool
    let onToggle: (TaskItem) -> Void
    let onSubmit: (TaskItem) -> Void
    let onTitleChange: (TaskItem, String) -> Void
    let onDelete: (TaskItem) -> Void
    let onSelect: () -> Void
    let onStartEdit: () -> Void
    let onEndEdit: () -> Void
    @FocusState.Binding var focusedField: TaskListView.FocusField?

    @State private var editingTitle: String = ""

    init(
        task: TaskItem,
        taskID: UUID,
        isSelected: Bool,
        isEditing: Bool = false,
        focusedField: FocusState<TaskListView.FocusField?>.Binding,
        onToggle: @escaping (TaskItem) -> Void,
        onSubmit: @escaping (TaskItem) -> Void,
        onTitleChange: @escaping (TaskItem, String) -> Void,
        onDelete: @escaping (TaskItem) -> Void,
        onSelect: @escaping () -> Void,
        onStartEdit: @escaping () -> Void = {},
        onEndEdit: @escaping () -> Void = {}
    ) {
        self.task = task
        self.taskID = taskID
        self.isSelected = isSelected
        self.isEditing = isEditing
        self.onToggle = onToggle
        self.onSubmit = onSubmit
        self.onTitleChange = onTitleChange
        self.onDelete = onDelete
        self.onSelect = onSelect
        self.onStartEdit = onStartEdit
        self.onEndEdit = onEndEdit
        _focusedField = focusedField
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

            if isEditing {
                TextField("New task", text: $editingTitle, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(1...5)
                    .focused($focusedField, equals: .task(taskID))
                    .onSubmit {
                        onSubmit(task)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(task.isCompleted)
            } else {
                HStack(spacing: 0) {
                    Text(task.title.isEmpty ? "New task" : task.title)
                        .font(.body)
                        .foregroundStyle(task.title.isEmpty ? .secondary : (task.isCompleted ? .secondary : .primary))
                        .strikethrough(task.isCompleted, color: .secondary)
                        .modifier(TextHoverModifier(isCompleted: task.isCompleted))
                        .onTapGesture {
                            if !task.isCompleted {
                                onStartEdit()
                            }
                        }

                    Spacer(minLength: 0)
                }
            }
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
        .onChange(of: editingTitle) {
            guard !task.isCompleted else { return }
            onTitleChange(task, editingTitle)
        }
        .onChange(of: isEditing) { _, newValue in
            if newValue {
                editingTitle = task.title
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if newValue == .task(taskID) && oldValue != .task(taskID) {
                onSelect()
            } else if oldValue == .task(taskID) && newValue != .task(taskID) {
                onEndEdit()
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
        let text = isEditing ? editingTitle : task.title
        guard !text.isEmpty else { return }
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    private func pasteFromPasteboard() {
        #if os(macOS)
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        #else
        guard let string = UIPasteboard.general.string else { return }
        #endif
        if isEditing {
            editingTitle = string
        }
        onTitleChange(task, string)
    }
}
