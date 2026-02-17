import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let taskID: UUID
    let index: Int
    let totalTasks: Int
    let isSelected: Bool
    @Binding var isDragging: Bool
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
    @State private var cachedAccentColor: Color = .clear

    init(
        task: TaskItem,
        taskID: UUID,
        index: Int = 0,
        totalTasks: Int = 1,
        isSelected: Bool,
        isDragging: Binding<Bool> = .constant(false),
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
        _isDragging = isDragging
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

            TappableTextField(
                text: $editingTitle,
                isCompleted: task.isCompleted,
                onEditingChanged: { editing, shouldCreateNewTask in
                    isCurrentlyEditing = editing
                    if editing { onStartEdit(taskID) }
                    else { onEndEdit(taskID, shouldCreateNewTask) }
                }
            )
            .focused($focusedField, equals: .task(taskID))
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .background(cardBackground)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: task.isCompleted ? 0 : 14,
                topTrailingRadius: task.isCompleted ? 0 : 14
            )
        )
        .overlay {
            if isSelected && !task.isCompleted {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 14, topTrailingRadius: 14
                )
                .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
        .overlay(alignment: .leading) {
            if !task.isCompleted {
                Rectangle()
                    .fill(cachedAccentColor)
                    .frame(width: 8)
            }
        }
        .onAppear {
            editingTitle = task.title
            cachedAccentColor = computeAccentColor()
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
        .onChange(of: index) { _, _ in
            cachedAccentColor = computeAccentColor()
        }
        .onChange(of: totalTasks) { _, _ in
            cachedAccentColor = computeAccentColor()
        }
        .onChange(of: isDragging) { _, dragging in
            if dragging {
                swipeOffset = 0
                swipeDirection = .none
                isSwipeTriggered = false
            }
        }
        .taskSwipeGesture(
            isDragging: $isDragging,
            swipeOffset: $swipeOffset,
            swipeDirection: $swipeDirection,
            isTriggered: $isSwipeTriggered,
            completeColor: cachedAccentColor,
            onComplete: { onToggle(task) },
            onDelete: { onDelete(task) }
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: task.isCompleted ? 0 : 14,
                topTrailingRadius: task.isCompleted ? 0 : 14
            )
        )
    }

    private func computeAccentColor() -> Color {
        guard !task.isCompleted else { return .clear }
        return taskColor(forIndex: index, total: totalTasks)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if task.isCompleted {
            Color.clear
        } else {
            Color.taskCard
        }
    }
}
