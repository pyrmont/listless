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

        // Set sortOrder to end of active tasks
        let activeTasks = fetchTasks().filter { !$0.isCompleted }
        let maxOrder = activeTasks.map(\.sortOrder).max() ?? 0
        task.sortOrder = maxOrder + 1000

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

    func moveTask(taskID: UUID, toIndex: Int) {
        let activeTasks = fetchTasks().filter { !$0.isCompleted }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let currentIndex = activeTasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard currentIndex != toIndex else { return }

        var reordered = activeTasks
        let task = reordered.remove(at: currentIndex)

        // Clamp toIndex to valid range after removal
        let insertIndex = min(toIndex, reordered.count)
        reordered.insert(task, at: insertIndex)

        // Reassign sortOrder with gaps of 1000
        for (index, task) in reordered.enumerated() {
            task.sortOrder = Int64(index) * 1000
        }

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
