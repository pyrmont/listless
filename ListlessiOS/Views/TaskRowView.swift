import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let taskID: UUID
    let index: Int
    let totalTasks: Int
    let isSelected: Bool
    let isEditing: Bool
    let onToggle: (TaskItem) -> Void
    let onTitleChange: (TaskItem, String) -> Void
    let onDelete: (TaskItem) -> Void
    let onSelect: (UUID) -> Void
    let onStartEdit: (UUID) -> Void
    let onEndEdit: (UUID, _ shouldCreateNewTask: Bool) -> Void
    @FocusState.Binding var focusedField: TaskListView.FocusField?

    @State private var editingTitle: String = ""
    @State private var isCurrentlyEditing: Bool = false
    @State private var submittedViaReturn = false

    private let horizontalPadding: CGFloat = 16
    private let checkboxTextSpacing: CGFloat = 12
    @ScaledMetric private var checkboxSize: CGFloat = 20

    private var dividerInset: CGFloat {
        horizontalPadding + checkboxSize + checkboxTextSpacing
    }

    init(
        task: TaskItem,
        taskID: UUID,
        index: Int = 0,
        totalTasks: Int = 1,
        isSelected: Bool,
        isEditing: Bool = false,
        focusedField: FocusState<TaskListView.FocusField?>.Binding,
        onToggle: @escaping (TaskItem) -> Void,
        onTitleChange: @escaping (TaskItem, String) -> Void,
        onDelete: @escaping (TaskItem) -> Void,
        onSelect: @escaping (UUID) -> Void,
        onStartEdit: @escaping (UUID) -> Void = { _ in },
        onEndEdit: @escaping (UUID, _ shouldCreateNewTask: Bool) -> Void = { _, _ in }
    ) {
        self.task = task
        self.taskID = taskID
        self.index = index
        self.totalTasks = totalTasks
        self.isSelected = isSelected
        self.isEditing = isEditing
        self.onToggle = onToggle
        self.onTitleChange = onTitleChange
        self.onDelete = onDelete
        self.onSelect = onSelect
        self.onStartEdit = onStartEdit
        self.onEndEdit = onEndEdit
        _focusedField = focusedField
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                onToggle(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .font(.system(size: 17))
                    .fontWeight(.thin)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("task-checkbox")
            .accessibilityValue(task.isCompleted ? "checkmark.circle.fill" : "circle")

            TextField("New task", text: $editingTitle, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...5)
                .focused($focusedField, equals: .task(taskID))
                .onSubmit {
                    // Return key pressed - mark for new task creation
                    submittedViaReturn = true
                    focusedField = nil
                }
                .disabled(task.isCompleted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(
                    isCurrentlyEditing ? "task-textfield" : "task-text-\(task.title)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(taskID)
        }
        .background(selectionBackground)
        .overlay(alignment: .bottom) {
            // Hairline border between rows, inset to align with text
            // Only show for active (non-completed) tasks
            if !task.isCompleted {
                Rectangle()
                    .fill(.separator)
                    .frame(height: 0.5)
                    .padding(.leading, dividerInset)
            }
        }
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
        .onChange(of: task.title) { _, newValue in
            // Keep editingTitle in sync with task.title when not editing
            if !isCurrentlyEditing {
                editingTitle = newValue
            }
        }
        .onChange(of: focusedField) { _, newValue in
            let isFocused = newValue == .task(taskID)
            if isFocused {
                // Focus gained
                isCurrentlyEditing = true
                onStartEdit(taskID)
            } else if isCurrentlyEditing {
                // Focus lost - check if it was via Return key
                isCurrentlyEditing = false
                onEndEdit(taskID, submittedViaReturn)
                submittedViaReturn = false
            }
        }
        .onAppear {
            // Initialize editingTitle
            editingTitle = task.title
        }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor.opacity(0.2))
        }
    }

    private func cutToPasteboard() {
        copyToPasteboard()
        onDelete(task)
    }

    private func copyToPasteboard() {
        let text = isEditing ? editingTitle : task.title
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
    }

    private func pasteFromPasteboard() {
        guard let string = UIPasteboard.general.string else { return }
        if isEditing {
            editingTitle = string
        }
        onTitleChange(task, string)
    }
}
