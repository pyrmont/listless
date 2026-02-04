import SwiftUI

struct TaskListView: View {
    enum FocusField: Hashable {
        case task(UUID)
        case scrollView
    }

    @State private var store: TaskStore
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TaskItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true),
        ],
        animation: .default
    )
    private var tasks: FetchedResults<TaskItem>
    @FocusState private var focusedField: FocusField?
    @State private var selectedTaskID: UUID?
    @State private var refreshID = UUID()

    init(store: TaskStore = TaskStore()) {
        _store = State(wrappedValue: store)
    }

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    if !completedTasks.isEmpty {
                        Text("Completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                            .padding(.bottom, 6)
                    }

                    ForEach(completedTasks) { task in
                        TaskRowView(
                            task: task,
                            taskID: task.id,
                            isSelected: selectedTaskID == task.id,
                            focusedField: $focusedField,
                            onToggle: toggleCompletion(_:),
                            onSubmit: handleSubmit(_:),
                            onTitleChange: updateTitle(_:_:),
                            onDelete: deleteTask(_:),
                            onSelect: { selectTask(task.id) }
                        )
                    }

                    if !activeTasks.isEmpty && !completedTasks.isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                    }

                    ForEach(activeTasks) { task in
                        TaskRowView(
                            task: task,
                            taskID: task.id,
                            isSelected: selectedTaskID == task.id,
                            focusedField: $focusedField,
                            onToggle: toggleCompletion(_:),
                            onSubmit: handleSubmit(_:),
                            onTitleChange: updateTitle(_:_:),
                            onDelete: deleteTask(_:),
                            onSelect: { selectTask(task.id) }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .onChange(of: selectedTaskID) { oldValue, newValue in
                    if let newValue {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleBackgroundTap()
        }
        .focusable()
        .focused($focusedField, equals: .scrollView)
        .focusEffectDisabled()
        .keyboardNavigation(
            onUpArrow: navigateUp,
            onDownArrow: navigateDown,
            onSpace: toggleSelectedTask,
            onReturn: focusSelectedTask,
            onEscape: unfocusTextField
        )
        .onAppear {
            focusScrollView()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            handleFocusChange(from: oldValue, to: newValue)
        }
    }

    private var activeTasks: [TaskItem] {
        Array(tasks.filter { !$0.isCompleted })
    }

    private var completedTasks: [TaskItem] {
        Array(tasks.filter { $0.isCompleted })
    }

    private var allTasksInDisplayOrder: [TaskItem] {
        completedTasks + activeTasks
    }

    private func createTaskAndFocus() {
        let task = store.createTask(title: "")
        selectedTaskID = task.id
        focusTextField(task.id)
    }

    private func handleBackgroundTap() {
        if focusedField != nil || selectedTaskID != nil {
            focusScrollView()
            selectedTaskID = nil
        } else {
            createTaskAndFocus()
        }
    }

    private func handleFocusChange(from oldValue: FocusField?, to newValue: FocusField?) {
        let oldID = taskID(from: oldValue)
        let newID = taskID(from: newValue)

        guard oldID != newID, let oldID else { return }
        deleteIfEmpty(taskID: oldID)
    }

    private func taskID(from field: FocusField?) -> UUID? {
        guard case let .task(id) = field else { return nil }
        return id
    }

    private func deleteIfEmpty(taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        let trimmedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty else { return }
        deleteTask(task)
    }

    private func handleSubmit(_ task: TaskItem) {
        createTaskAndFocus()
    }

    private func updateTitle(_ task: TaskItem, _ title: String) {
        guard task.title != title else { return }
        store.update(taskID: task.id, title: title)
    }

    private func toggleCompletion(_ task: TaskItem) {
        if task.isCompleted {
            store.uncomplete(taskID: task.id)
        } else {
            store.complete(taskID: task.id)
        }
    }

    private func selectTask(_ taskID: UUID) {
        selectedTaskID = taskID
    }

    private func deleteTask(_ task: TaskItem) {
        let taskID = task.id
        if focusedField == .task(taskID) {
            focusScrollView()
        }
        if selectedTaskID == taskID {
            selectedTaskID = nil
        }
        store.delete(taskID: taskID)
    }

    private func navigateUp() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }

        guard let currentID = selectedTaskID else {
            selectedTaskID = activeTasks.last?.id
            return .handled
        }

        let displayOrder = allTasksInDisplayOrder
        guard let currentIndex = displayOrder.firstIndex(where: { $0.id == currentID }) else {
            return .handled
        }

        if currentIndex > 0 {
            selectedTaskID = displayOrder[currentIndex - 1].id
        }
        return .handled
    }

    private func navigateDown() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }

        guard let currentID = selectedTaskID else {
            selectedTaskID = completedTasks.first?.id ?? activeTasks.first?.id
            return .handled
        }

        let displayOrder = allTasksInDisplayOrder
        guard let currentIndex = displayOrder.firstIndex(where: { $0.id == currentID }) else {
            return .handled
        }

        if currentIndex < displayOrder.count - 1 {
            selectedTaskID = displayOrder[currentIndex + 1].id
        }
        return .handled
    }

    private func toggleSelectedTask() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }
        guard let currentID = selectedTaskID else { return .handled }
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else { return .handled }
        toggleCompletion(task)
        return .handled
    }

    private func focusSelectedTask() -> KeyPress.Result {
        guard focusedField == .scrollView else { return .ignored }
        guard let currentID = selectedTaskID else { return .handled }
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else { return .handled }
        guard !task.isCompleted else { return .handled }
        focusTextField(currentID)
        return .handled
    }

    private func unfocusTextField() -> KeyPress.Result {
        guard case .task = focusedField else { return .ignored }
        focusScrollView()
        return .handled
    }

    // MARK: - Focus Management

    private func focusScrollView() {
        focusedField = .scrollView
    }

    private func focusTextField(_ taskID: UUID) {
        focusedField = .task(taskID)
    }
}
