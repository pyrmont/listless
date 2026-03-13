import Foundation
import CoreData
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

@Suite("TaskStore Edge Cases", .serialized)
@MainActor
struct TaskStoreEdgeCaseTests {

    // MARK: - Title Edge Cases

    @Test("Task with empty title")
    func taskWithEmptyTitle() async throws {
        let store = makeTestStore()

        let task = try store.createTask(title: "")

        let tasks = try store.fetchTasks()
        #expect(tasks.first?.title == "")
    }

    @Test("Task with very long title")
    func taskWithVeryLongTitle() async throws {
        let store = makeTestStore()
        let longTitle = String(repeating: "A", count: 10_000)

        let task = try store.createTask(title: longTitle)

        let tasks = try store.fetchTasks()
        #expect(tasks.first?.title.count == 10_000)
    }

    @Test("Task with special characters")
    func taskWithSpecialCharacters() async throws {
        let store = makeTestStore()
        let specialTitle = "Test 🎉 with émojis & spëcial çharacters! @#$%^&*()"

        let task = try store.createTask(title: specialTitle)

        let tasks = try store.fetchTasks()
        #expect(tasks.first?.title == specialTitle)
    }

    @Test("Task with newlines and tabs")
    func taskWithNewlinesAndTabs() async throws {
        let store = makeTestStore()
        let multilineTitle = "Line 1\nLine 2\tTabbed"

        let task = try store.createTask(title: multilineTitle)

        let tasks = try store.fetchTasks()
        #expect(tasks.first?.title == multilineTitle)
    }

    // MARK: - Large Data Sets

    @Test("Create many tasks")
    func createManyTasks() async throws {
        let store = makeTestStore()
        let count = 100

        for i in 0..<count {
            _ = try store.createTask(title: "Task \(i)")
        }

        let tasks = try store.fetchTasks()
        #expect(tasks.count == count)
    }

    @Test("Delete all tasks from large set")
    func deleteAllTasksFromLargeSet() async throws {
        let store = makeTestStore()
        var taskIDs: [UUID] = []

        for i in 0..<50 {
            let task = try store.createTask(title: "Task \(i)")
            taskIDs.append(task.id)
        }

        for id in taskIDs {
            try store.delete(taskID: id)
        }

        let tasks = try store.fetchTasks()
        #expect(tasks.isEmpty)
    }

    // MARK: - State Transitions

    @Test("Create task after completing all tasks")
    func createTaskAfterCompletingAllTasks() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 3)

        for id in taskIDs {
            try store.complete(taskID: id)
        }

        let newTask = try store.createTask(title: "New task")

        let tasks = try store.fetchTasks()
        let activeTasks = tasks.filter { !$0.isCompleted }
        #expect(activeTasks.count == 1)
        #expect(activeTasks[0].id == newTask.id)
    }

    @Test("Rapid updates to same task")
    func rapidUpdatesToSameTask() async throws {
        let store = makeTestStore()
        let task = try store.createTask(title: "Original")

        for i in 0..<10 {
            try store.update(taskID: task.id, title: "Update \(i)")
        }

        let tasks = try store.fetchTasks()
        #expect(tasks.first?.title == "Update 9")
    }

    // MARK: - Store State Tests

    @Test("Store with only completed tasks")
    func storeWithOnlyCompletedTasks() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 5)

        for id in taskIDs {
            try store.complete(taskID: id)
        }

        let tasks = try store.fetchTasks()
        #expect(tasks.allSatisfy { $0.isCompleted })
        #expect(tasks.count == 5)
    }

    @Test("SortOrder after completing all tasks")
    func sortOrderAfterCompletingAllTasks() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 3)

        for id in taskIDs {
            try store.complete(taskID: id)
        }

        let newTask1 = try store.createTask(title: "New 1")
        let newTask2 = try store.createTask(title: "New 2")

        let activeTasks = try store.fetchTasks().filter { !$0.isCompleted }
        #expect(activeTasks[0].id == newTask1.id)
        #expect(activeTasks[1].id == newTask2.id)
        #expect(activeTasks[1].sortOrder > activeTasks[0].sortOrder)
    }

    @Test("Uncompleting task moves it back to active")
    func uncompletingTaskMovesItBackToActive() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 3)
        try store.complete(taskID: taskIDs[1])

        try store.uncomplete(taskID: taskIDs[1])

        let tasks = try store.fetchTasks()
        let activeTasks = tasks.filter { !$0.isCompleted }
        #expect(activeTasks.count == 3)
        #expect(activeTasks.contains { $0.id == taskIDs[1] })
    }

    @Test("Uncomplete legacy sortOrder zero conflict appends to end")
    func uncompleteLegacyZeroConflictAppendsToEnd() async throws {
        let store = makeTestStore()
        let activeTask = try store.createTask(title: "Active")
        let completedTask = try store.createTask(title: "Completed")

        activeTask.sortOrder = 0
        try store.complete(taskID: completedTask.id)
        completedTask.sortOrder = 0
        try store.save()

        try store.uncomplete(taskID: completedTask.id)

        let activeTasks = try store.fetchTasks().filter { !$0.isCompleted }
            .sorted { $0.sortOrder < $1.sortOrder }
        #expect(activeTasks.count == 2)
        #expect(activeTasks[0].id == activeTask.id)
        #expect(activeTasks[1].id == completedTask.id)
        #expect(activeTasks[1].sortOrder > activeTasks[0].sortOrder)
    }

    @Test("Merge policy prefers store when store updatedAt is newer")
    func mergePolicyPrefersStoreWhenStoreIsNewer() async throws {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.viewContext
        viewContext.automaticallyMergesChangesFromParent = false

        let task = TaskItem(context: viewContext)
        task.title = "Original"
        task.updatedAt = Date(timeIntervalSince1970: 100)
        try viewContext.save()

        let taskID = task.id

        let backgroundContext = controller.container.newBackgroundContext()
        try await backgroundContext.perform {
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)
            request.fetchLimit = 1

            guard let remote = try backgroundContext.fetch(request).first else {
                Issue.record("Expected task to exist in background context")
                return
            }

            remote.title = "Remote newer"
            remote.updatedAt = Date(timeIntervalSince1970: 200)
            try backgroundContext.save()
        }

        task.updatedAt = Date(timeIntervalSince1970: 150)
        try viewContext.save()

        let verifyContext = controller.container.newBackgroundContext()
        try await verifyContext.perform {
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)
            request.fetchLimit = 1

            guard let resolved = try verifyContext.fetch(request).first else {
                Issue.record("Expected task to exist in verify context")
                return
            }

            #expect(resolved.title == "Remote newer")
            #expect(resolved.updatedAt == Date(timeIntervalSince1970: 200))
        }
    }

    @Test("Merge policy prefers local when local updatedAt is newer")
    func mergePolicyPrefersLocalWhenLocalIsNewer() async throws {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.viewContext
        viewContext.automaticallyMergesChangesFromParent = false

        let task = TaskItem(context: viewContext)
        task.title = "Original"
        task.updatedAt = Date(timeIntervalSince1970: 100)
        try viewContext.save()

        let taskID = task.id

        let backgroundContext = controller.container.newBackgroundContext()
        try await backgroundContext.perform {
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)
            request.fetchLimit = 1

            guard let remote = try backgroundContext.fetch(request).first else {
                Issue.record("Expected task to exist in background context")
                return
            }

            remote.title = "Remote older"
            remote.updatedAt = Date(timeIntervalSince1970: 200)
            try backgroundContext.save()
        }

        task.updatedAt = Date(timeIntervalSince1970: 300)
        try viewContext.save()

        let verifyContext = controller.container.newBackgroundContext()
        try await verifyContext.perform {
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)
            request.fetchLimit = 1

            guard let resolved = try verifyContext.fetch(request).first else {
                Issue.record("Expected task to exist in verify context")
                return
            }

            #expect(resolved.title == "Original")
            #expect(resolved.updatedAt == Date(timeIntervalSince1970: 300))
        }
    }
}
