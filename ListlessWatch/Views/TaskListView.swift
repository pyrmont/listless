import CoreData
import SwiftUI

struct TaskListView: View {
    let store: TaskStore
    let syncMonitor: CloudKitSyncMonitor

    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\TaskItem.isCompleted, order: .forward),
            SortDescriptor(\TaskItem.sortOrder, order: .forward),
        ],
        animation: .default
    )
    private var tasks: FetchedResults<TaskItem>

    var body: some View {
        let activeTasks = tasks.filter { !$0.isCompleted }
        let completedTasks = tasks.filter { $0.isCompleted }

        NavigationStack {
            Group {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "checklist",
                        description: Text("Add items on your iPhone or Mac.")
                    )
                } else {
                    List {
                        ForEach(Array(activeTasks.enumerated()), id: \.element.id) { index, task in
                            TaskRowView(
                                task: task,
                                index: index,
                                totalActive: activeTasks.count,
                                onToggle: { toggleTask($0) }
                            )
                        }

                        if !completedTasks.isEmpty {
                            Section("Completed") {
                                ForEach(completedTasks) { task in
                                    TaskRowView(
                                        task: task,
                                        index: 0,
                                        totalActive: 0,
                                        onToggle: { toggleTask($0) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Listless")
        }
    }

    private func toggleTask(_ task: TaskItem) {
        do {
            if task.isCompleted {
                try store.uncomplete(taskID: task.id)
            } else {
                try store.complete(taskID: task.id)
            }
        } catch {
            // Sync monitor handles error reporting
        }
    }
}
