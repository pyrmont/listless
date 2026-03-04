import SwiftUI

extension TaskListView {

    func deleteTaskWithUndo(_ task: TaskItem) {
        deleteTask(task)
        showUndoToast(message: "Task deleted")
    }

    func deleteSelectedTaskWithUndo() -> KeyPress.Result {
        guard focusedField == .scrollView else {
            return .ignored
        }
        guard let currentID = selectedTaskID else {
            return .handled
        }
        guard let task = allTasksInDisplayOrder.first(where: { $0.id == currentID }) else {
            return .handled
        }
        deleteTaskWithUndo(task)
        return .handled
    }

    func clearCompletedTasksWithUndo() {
        let ids = completedTasks.map(\.id)
        guard !ids.isEmpty else { return }
        let count = ids.count
        managedObjectContext.undoManager?.beginUndoGrouping()
        do {
            try store.deleteMultiple(taskIDs: ids)
        } catch {
            presentStoreError(error)
            managedObjectContext.undoManager?.endUndoGrouping()
            return
        }
        managedObjectContext.undoManager?.endUndoGrouping()
        let noun = count == 1 ? "task" : "tasks"
        showUndoToast(message: "\(count) completed \(noun) cleared")
    }

    func showUndoToast(message: String) {
        withAnimation {
            undoToast = UndoToastData(id: UUID(), message: message)
        }
    }

    func performUndo() {
        managedObjectContext.undoManager?.undo()
        do {
            try store.save()
        } catch {
            presentStoreError(error)
        }
        dismissUndoToast()
    }

    func dismissUndoToast() {
        withAnimation {
            undoToast = nil
        }
    }
}
