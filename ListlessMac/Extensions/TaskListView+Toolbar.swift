import SwiftUI

extension TaskListView {
    @ToolbarContentBuilder
    var platformToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Spacer()
        }

        ToolbarItemGroup(placement: .automatic) {
            HStack {
                Button {
                    createNewTask()
                    // Trigger focus resolution by setting to nil
                    focusedField = nil
                } label: {
                    Label("New Task", systemImage: "plus")
                }
                .help("Create a new task")

                Button {
                    if let currentID = selectedTaskID,
                        let task = allTasksInDisplayOrder.first(where: { $0.id == currentID })
                    {
                        deleteTask(task)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedTaskID == nil || focusedField != .scrollView)
                .help("Delete selected task")

                Divider()

                Button {
                    clearCompletedTasks()
                } label: {
                    Label("Clear Completed", systemImage: "tray")
                }
                .disabled(completedTasks.isEmpty)
                .help("Clear all completed tasks")
            }
        }
    }
}
