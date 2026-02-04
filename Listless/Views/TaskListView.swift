import SwiftUI

struct TaskListView: View {
    enum FocusField: Hashable {
        case task(UUID)
    }

    @State private var store: TaskStore
    @State private var tasks: [TaskItem] = []
    @FocusState private var focusedField: FocusField?
    @FocusState private var scrollViewFocused: Bool
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
            print("TaskListView: background tap")
            handleBackgroundTap()
        }
        .focusable()
        .focused($scrollViewFocused)
        .focusEffectDisabled()
        .keyboardNavigation(
            onUpArrow: navigateUp,
            onDownArrow: navigateDown
        )
        .onAppear {
            reloadTasks()
            scrollViewFocused = true
        }
        .onChange(of: focusedField) { oldValue, newValue in
            handleFocusChange(from: oldValue, to: newValue)
            // When a text field gets focus, remove ScrollView focus
            // When text field loses focus, restore ScrollView focus
            scrollViewFocused = (newValue == nil)
        }
    }

    private var activeTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [TaskItem] {
        tasks.filter { $0.isCompleted }
    }

    private var allTasksInDisplayOrder: [TaskItem] {
        completedTasks + activeTasks
    }

    private func reloadTasks() {
        tasks = store.fetchTasks()
    }

    private func createTaskAndFocus() {
        let task = store.createTask(title: "")
        reloadTasks()
        selectedTaskID = task.id
        focusedField = .task(task.id)
    }

    private func handleBackgroundTap() {
        if focusedField != nil || selectedTaskID != nil {
            focusedField = nil
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
        reloadTasks()
        refreshID = UUID()
    }

    private func selectTask(_ taskID: UUID) {
        selectedTaskID = taskID
    }

    private func deleteTask(_ task: TaskItem) {
        let taskID = task.id
        if focusedField == .task(taskID) {
            focusedField = nil
        }
        if selectedTaskID == taskID {
            selectedTaskID = nil
        }
        store.delete(taskID: taskID)
        reloadTasks()
    }

    private func navigateUp() {
        print("TaskListView: navigateUp called, selectedTaskID: \(String(describing: selectedTaskID))")
        guard let currentID = selectedTaskID else {
            selectedTaskID = activeTasks.last?.id
            print("TaskListView: No selection, selected last active: \(String(describing: selectedTaskID))")
            return
        }

        let displayOrder = allTasksInDisplayOrder
        guard let currentIndex = displayOrder.firstIndex(where: { $0.id == currentID }) else {
            print("TaskListView: Current task not found in display order")
            return
        }

        if currentIndex > 0 {
            selectedTaskID = displayOrder[currentIndex - 1].id
            print("TaskListView: Moved to previous task: \(String(describing: selectedTaskID))")
        }
    }

    private func navigateDown() {
        print("TaskListView: navigateDown called, selectedTaskID: \(String(describing: selectedTaskID))")
        guard let currentID = selectedTaskID else {
            selectedTaskID = completedTasks.first?.id ?? activeTasks.first?.id
            print("TaskListView: No selection, selected first: \(String(describing: selectedTaskID))")
            return
        }

        let displayOrder = allTasksInDisplayOrder
        guard let currentIndex = displayOrder.firstIndex(where: { $0.id == currentID }) else {
            print("TaskListView: Current task not found in display order")
            return
        }

        if currentIndex < displayOrder.count - 1 {
            selectedTaskID = displayOrder[currentIndex + 1].id
            print("TaskListView: Moved to next task: \(String(describing: selectedTaskID))")
        }
    }
}
