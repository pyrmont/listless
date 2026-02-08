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

    private let horizontalPadding: CGFloat = 16
    private let checkboxTextSpacing: CGFloat = 12
    @ScaledMetric private var checkboxSize: CGFloat = 20

    private var dividerInset: CGFloat {
        horizontalPadding + checkboxSize + checkboxTextSpacing
    }

    private var accentColor: Color {
        guard !task.isCompleted else { return .clear }
        guard totalTasks > 1 else { return Color(hue: 0.98, saturation: 0.85, brightness: 1.0) }

        // Gradient matches gradient.png: coral/red → pink/magenta → purple/blue
        let progress = Double(index) / Double(totalTasks - 1)

        // Define color stops based on the gradient image
        let topColor = Color(hue: 0.98, saturation: 0.85, brightness: 1.0)  // Coral/red
        let midColor = Color(hue: 0.88, saturation: 0.75, brightness: 0.95)  // Pink/magenta
        let bottomColor = Color(hue: 0.72, saturation: 0.65, brightness: 0.85)  // Purple/blue

        // Interpolate between colors
        if progress < 0.5 {
            // Top half: coral → magenta
            let localProgress = progress * 2.0
            return interpolateColor(from: topColor, to: midColor, progress: localProgress)
        } else {
            // Bottom half: magenta → purple/blue
            let localProgress = (progress - 0.5) * 2.0
            return interpolateColor(from: midColor, to: bottomColor, progress: localProgress)
        }
    }

    private func interpolateColor(from: Color, to: Color, progress: Double) -> Color {
        // Extract HSB components and interpolate
        let fromHSB = PlatformColor(from).hsba
        let toHSB = PlatformColor(to).hsba

        let hue = fromHSB.hue + (toHSB.hue - fromHSB.hue) * progress
        let saturation = fromHSB.saturation + (toHSB.saturation - fromHSB.saturation) * progress
        let brightness = fromHSB.brightness + (toHSB.brightness - fromHSB.brightness) * progress

        return Color(hue: hue, saturation: saturation, brightness: brightness)
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
        .overlay(alignment: .leading) {
            // Colored accent bar on the left edge
            Rectangle()
                .fill(accentColor)
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
        .onAppear {
            // Initialize editingTitle
            editingTitle = task.title
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
