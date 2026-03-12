import SwiftUI

extension TaskListView {
    @ToolbarContentBuilder
    var platformToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Spacer()
        }

        ToolbarItemGroup(placement: .automatic) {
            HStack {
                if syncMonitor.hasDiagnosticsIssue {
                    Button {
                        NSApp.sendAction(
                            #selector(AppDelegate.handleShowSyncDiagnostics),
                            to: nil, from: nil
                        )
                    } label: {
                        Label("Sync Issues", systemImage: "exclamationmark.icloud")
                    }
                    .help("View sync diagnostics")

                    Divider()
                }

                Button {
                    createNewTask()
                    // Trigger focus resolution by setting to nil
                    focusedField = nil
                } label: {
                    Label("New Item", systemImage: "plus")
                }
                .help("Create a new item")

                Button {
                    if let currentID = fState.selectedTaskID,
                        let task = allTasksInDisplayOrder.first(where: { $0.id == currentID })
                    {
                        deleteTask(task)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(fState.selectedTaskID == nil || focusedField != .scrollView)
                .help("Delete selected item")

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
