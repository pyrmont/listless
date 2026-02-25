import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let taskID: UUID
    let index: Int
    let totalTasks: Int
    let isSelected: Bool
    let onToggle: (TaskItem) -> Void
    let onTitleChange: (TaskItem, String) -> Void
    let onDelete: (TaskItem) -> Void
    let onSelect: (UUID) -> Void
    let onStartEdit: (UUID) -> Void
    let onEndEdit: (UUID, _ shouldCreateNewTask: Bool) -> Void
    let onPaste: (String) -> Void
    @FocusState.Binding var focusedField: TaskListView.FocusField?

    @State private var editingTitle: String = ""
    @State private var isCurrentlyEditing: Bool = false
    @State private var cachedAccentColor: Color = .clear

    private let horizontalPadding: CGFloat = 16
    private let checkboxTextSpacing: CGFloat = 12
    @ScaledMetric private var checkboxSize: CGFloat = 20

    private var dividerInset: CGFloat {
        horizontalPadding + checkboxSize + checkboxTextSpacing
    }

    @MainActor
    private func computeAccentColor() -> Color {
        guard !task.isCompleted else { return .clear }
        return cachedTaskColor(forIndex: index, total: totalTasks)
    }

    init(
        task: TaskItem,
        taskID: UUID,
        index: Int = 0,
        totalTasks: Int = 1,
        isSelected: Bool,
        focusedField: FocusState<TaskListView.FocusField?>.Binding,
        onToggle: @escaping (TaskItem) -> Void,
        onTitleChange: @escaping (TaskItem, String) -> Void,
        onDelete: @escaping (TaskItem) -> Void,
        onSelect: @escaping (UUID) -> Void,
        onStartEdit: @escaping (UUID) -> Void = { _ in },
        onEndEdit: @escaping (UUID, _ shouldCreateNewTask: Bool) -> Void = { _, _ in },
        onPaste: @escaping (String) -> Void = { _ in }
    ) {
        self.task = task
        self.taskID = taskID
        self.index = index
        self.totalTasks = totalTasks
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onTitleChange = onTitleChange
        self.onDelete = onDelete
        self.onSelect = onSelect
        self.onStartEdit = onStartEdit
        self.onEndEdit = onEndEdit
        self.onPaste = onPaste
        _focusedField = focusedField
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button {
                onToggle(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .font(.system(size: 17))
                    .fontWeight(.thin)
            }
            .buttonStyle(.borderless)
            .alignmentGuide(.firstTextBaseline) { d in
                d[VerticalAlignment.center] + 5
            }
            .accessibilityIdentifier("task-checkbox")
            .accessibilityValue(task.isCompleted ? "checkmark.circle.fill" : "circle")

            ClickableTextField(
                text: $editingTitle,
                isCompleted: task.isCompleted,
                onEditingChanged: { editing, shouldCreateNewTask in
                    isCurrentlyEditing = editing
                    if editing {
                        onStartEdit(taskID)
                    } else {
                        onEndEdit(taskID, shouldCreateNewTask)
                    }
                }
            )
            .focused($focusedField, equals: .task(taskID))
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
            if !task.isCompleted {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 6)
            }
        }
        .overlay(alignment: .leading) {
            // Colored accent bar on the left edge
            Rectangle()
                .fill(cachedAccentColor)
                .frame(width: 4)
                .padding(.vertical, 1)
        }
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
        .onChange(of: index) { _, _ in
            cachedAccentColor = computeAccentColor()
        }
        .onChange(of: totalTasks) { _, _ in
            cachedAccentColor = computeAccentColor()
        }
        .onAppear {
            // Initialize editingTitle and cache accent color (computed once)
            editingTitle = task.title
            cachedAccentColor = computeAccentColor()
        }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor.opacity(0.2))
        } else if task.isCompleted {
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private func cutToPasteboard() {
        copyToPasteboard()
        onDelete(task)
    }

    private func copyToPasteboard() {
        let text = isCurrentlyEditing ? editingTitle : task.title
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func pasteFromPasteboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        if isCurrentlyEditing {
            editingTitle = string
        } else {
            onPaste(string)
        }
    }
}
