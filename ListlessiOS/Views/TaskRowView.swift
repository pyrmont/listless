import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let taskID: UUID
    let isSelected: Bool
    let onToggle: (TaskItem) -> Void
    let onTitleChange: (TaskItem, String) -> Void
    let onDelete: (TaskItem) -> Void
    let onSelect: (UUID) -> Void
    let onStartEdit: (UUID) -> Void
    let onEndEdit: (UUID, _ shouldCreateNewTask: Bool) -> Void
    @FocusState.Binding var focusedField: TaskListView.FocusField?

    @State private var editingTitle: String = ""
    @State private var isCurrentlyEditing: Bool = false
    @State private var swipeOffset: CGFloat = 0
    @State private var swipeDirection: TaskRowSwipeGesture.SwipeDirection = .none
    @State private var isSwipeTriggered: Bool = false

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
        self.isSelected = isSelected
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
                // When a right-swipe is past the threshold, preview the toggled state
                let previewCompleted = isSwipeTriggered && swipeDirection == .right
                    ? !task.isCompleted
                    : task.isCompleted
                Image(systemName: previewCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(previewCompleted ? Color.secondary : Color.primary)
                    .font(.system(size: 17))
                    .fontWeight(.thin)
            }
            .buttonStyle(.borderless)

            TextField("Task", text: $editingTitle)
                .focused($focusedField, equals: .task(taskID))
                .font(.system(size: 18))
                .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                .strikethrough(task.isCompleted, color: .secondary)
                .disabled(task.isCompleted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onSubmit {
                    isCurrentlyEditing = false
                    onEndEdit(taskID, true)
                }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            // .onTapGesture (not .simultaneousGesture) lets the child Button suppress this
            // gesture for its own hit area, so circle button taps don't also fire here.
            // If tapping a completed row while another row is being edited, preserve
            // the current focus/selection.
            if task.isCompleted,
               let field = focusedField,
               case .task(let id) = field,
               id != taskID
            {
                return
            }
            onSelect(taskID)
            if !task.isCompleted {
                focusedField = .task(taskID)
            }
        }
        .background(selectionBackground)
        .overlay(alignment: .top) {
            if !task.isCompleted {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0.10), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 6)
                    Rectangle()
                        .fill(.black.opacity(0.4))
                        .frame(height: 0.5)
                }
            }
        }
        .onAppear {
            editingTitle = task.title
        }
        .onChange(of: editingTitle) {
            guard !task.isCompleted else { return }
            onTitleChange(task, editingTitle)
        }
        .onChange(of: task.title) { _, newValue in
            if !isCurrentlyEditing {
                editingTitle = newValue
            }
        }
        .onChange(of: focusedField) { _, newValue in
            let isNowEditing = newValue == .task(taskID)
            if isNowEditing && !isCurrentlyEditing {
                isCurrentlyEditing = true
                onStartEdit(taskID)
            } else if !isNowEditing && isCurrentlyEditing {
                isCurrentlyEditing = false
                onEndEdit(taskID, false)
            }
        }
        .taskSwipeGesture(
            isActive: true,
            isEditing: isCurrentlyEditing,
            isDragging: false,
            swipeOffset: $swipeOffset,
            swipeDirection: $swipeDirection,
            isTriggered: $isSwipeTriggered,
            onComplete: { onToggle(task) },
            onDelete: { onDelete(task) }
        )
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if task.isCompleted {
            Color(uiColor: .systemBackground)
        } else if isSelected {
            Color.accentColor.opacity(0.2)
        }
    }
}
