import CoreData
import Foundation

enum TaskStoreError: LocalizedError {
    case fetchFailed(Error)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to fetch tasks: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save changes: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class TaskStore {
    private let persistenceController: PersistenceController
    private var context: NSManagedObjectContext {
        persistenceController.viewContext
    }

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    func fetchTasks() throws -> [TaskItem] {
        do {
            let activeRequest = TaskItem.fetchRequest()
            activeRequest.predicate = NSPredicate(format: "isCompleted == NO")
            activeRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \TaskItem.sortOrder, ascending: true)
            ]

            let completedRequest = TaskItem.fetchRequest()
            completedRequest.predicate = NSPredicate(format: "isCompleted == YES")
            completedRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \TaskItem.updatedAt, ascending: false)
            ]

            let activeTasks = try context.fetch(activeRequest)
            let completedTasks = try context.fetch(completedRequest)

            return activeTasks + completedTasks
        } catch {
            throw TaskStoreError.fetchFailed(error)
        }
    }

    func createTask(title: String = "", atBeginning: Bool = false, sortOrder: Int64? = nil) throws -> TaskItem {
        let task = TaskItem(context: context)
        task.title = title

        if let sortOrder {
            task.sortOrder = sortOrder
        } else {
            context.processPendingChanges()
            let activeTasks = try fetchTasks().filter { !$0.isCompleted }

            if atBeginning {
                let minOrder = activeTasks.map(\.sortOrder).min() ?? 0
                task.sortOrder = minOrder - 1000
            } else {
                let maxOrder = activeTasks.map(\.sortOrder).max() ?? -1000
                task.sortOrder = maxOrder + 1000
            }
        }

        return task
    }

    func complete(taskID: UUID) throws {
        guard let task = try findTask(id: taskID) else { return }
        task.isCompleted = true
        try save()
    }

    func uncomplete(taskID: UUID) throws {
        guard let task = try findTask(id: taskID) else { return }
        let restoredSortOrder = task.sortOrder
        let activeTasks = try fetchTasks().filter { !$0.isCompleted && $0.id != task.id }
        let hasSortOrderConflict = activeTasks.contains { $0.sortOrder == restoredSortOrder }

        if hasSortOrderConflict {
            let maxSortOrder = activeTasks.map(\.sortOrder).max() ?? -1000
            task.sortOrder = maxSortOrder + 1000
        }

        task.isCompleted = false
        try save()
    }

    func update(taskID: UUID, title: String) throws {
        guard let task = try findTask(id: taskID) else { return }
        task.title = title
        try save()
    }

    func updateWithoutSaving(taskID: UUID, title: String) throws {
        guard let task = try findTask(id: taskID) else { return }
        task.title = title
        // Don't save - will be saved when editing ends
    }

    func delete(taskID: UUID) throws {
        guard let task = try findTask(id: taskID) else { return }
        context.delete(task)
        try save()
    }

    func deleteMultiple(taskIDs: [UUID]) throws {
        for taskID in taskIDs {
            guard let task = try findTask(id: taskID) else { continue }
            context.delete(task)
        }
        try save()
    }

    func normalizeSortOrders() throws {
        let activeTasks = try fetchTasks().filter { !$0.isCompleted }
            .sorted { $0.sortOrder < $1.sortOrder }

        for (index, task) in activeTasks.enumerated() {
            task.sortOrder = Int64(index) * 1000
        }

        try save()
    }

    func moveTask(taskID: UUID, toIndex: Int) throws {
        let activeTasks = try fetchTasks().filter { !$0.isCompleted }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let currentIndex = activeTasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard currentIndex != toIndex else { return }

        var reordered = activeTasks
        let task = reordered.remove(at: currentIndex)

        // Clamp toIndex to valid range [0, reordered.count] after removal
        let insertIndex = max(0, min(toIndex, reordered.count))
        reordered.insert(task, at: insertIndex)

        // Reassign sortOrder with gaps of 1000
        for (index, task) in reordered.enumerated() {
            task.sortOrder = Int64(index) * 1000
        }

        try save()
    }

    private func findTask(id: UUID) throws -> TaskItem? {
        let request = TaskItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            throw TaskStoreError.fetchFailed(error)
        }
    }

    func save() throws {
        try persistenceController.save()
    }
}
