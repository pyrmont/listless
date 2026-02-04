import Foundation
import CoreData
import Observation

@MainActor
@Observable
final class TaskStore {
    private let persistenceController: PersistenceController
    private var context: NSManagedObjectContext {
        persistenceController.viewContext
    }

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    func fetchTasks() -> [TaskItem] {
        let request = TaskItem.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true),
        ]

        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch tasks: \(error)")
            return []
        }
    }

    func createTask(title: String = "") -> TaskItem {
        let task = TaskItem(context: context)
        task.title = title
        save()
        return task
    }

    func complete(taskID: UUID) {
        guard let task = findTask(id: taskID) else { return }
        task.isCompleted = true
        save()
    }

    func uncomplete(taskID: UUID) {
        guard let task = findTask(id: taskID) else { return }
        task.isCompleted = false
        save()
    }

    func update(taskID: UUID, title: String) {
        guard let task = findTask(id: taskID) else { return }
        task.title = title
        save()
    }

    func delete(taskID: UUID) {
        guard let task = findTask(id: taskID) else { return }
        context.delete(task)
        save()
    }

    private func findTask(id: UUID) -> TaskItem? {
        let request = TaskItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to find task: \(error)")
            return nil
        }
    }

    private func save() {
        persistenceController.save()
    }
}
