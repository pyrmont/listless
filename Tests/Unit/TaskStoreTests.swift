import Foundation
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

@Suite("TaskStore CRUD Operations", .serialized)
@MainActor
struct TaskStoreTests {

    // MARK: - Creation Tests

    @Test("Create task with empty title")
    func createTaskWithEmptyTitle() async throws {
        let store = makeTestStore()

        let task = try store.createTask()

        #expect(task.title == "")
        #expect(task.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(task.isCompleted == false)
        #expect(task.createdAt.timeIntervalSinceNow > -1.0)
    }

    @Test("Create task with title")
    func createTaskWithTitle() async throws {
        let store = makeTestStore()

        let task = try store.createTask(title: "Buy groceries")

        #expect(task.title == "Buy groceries")
        #expect(task.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
    }

    @Test("Create multiple tasks with unique IDs")
    func createMultipleTasksWithUniqueIDs() async throws {
        let store = makeTestStore()

        let task1 = try store.createTask(title: "Task 1")
        let task2 = try store.createTask(title: "Task 2")
        let task3 = try store.createTask(title: "Task 3")

        #expect(task1.id != task2.id)
        #expect(task2.id != task3.id)
        #expect(task1.id != task3.id)
    }

    @Test("Created task has timestamps")
    func createdTaskHasTimestamps() async throws {
        let store = makeTestStore()

        let beforeCreate = Date()
        let task = try store.createTask(title: "Test")
        let afterCreate = Date()

        #expect(task.createdAt >= beforeCreate)
        #expect(task.createdAt <= afterCreate)
        #expect(task.updatedAt >= beforeCreate)
        #expect(task.updatedAt <= afterCreate)
    }

    @Test("Create task at beginning prepends to active tasks")
    func createTaskAtBeginningPrepends() async throws {
        let store = makeTestStore()

        let first = try store.createTask(title: "First")
        let second = try store.createTask(title: "Second")
        let prepended = try store.createTask(title: "Prepended", atBeginning: true)

        let tasks = try store.fetchTasks().filter { !$0.isCompleted }

        #expect(tasks.map(\.title) == ["Prepended", "First", "Second"])
        #expect(prepended.sortOrder < first.sortOrder)
        #expect(first.sortOrder < second.sortOrder)
    }

    // MARK: - Fetch Tests

    @Test("Fetch tasks from empty store")
    func fetchTasksFromEmptyStore() async throws {
        let store = makeTestStore()

        let tasks = try store.fetchTasks()

        #expect(tasks.isEmpty)
    }

    @Test("Fetch tasks returns created tasks")
    func fetchTasksReturnsCreatedTasks() async throws {
        let store = makeTestStore()
        _ = try store.createTask(title: "Task 1")
        _ = try store.createTask(title: "Task 2")

        let tasks = try store.fetchTasks()

        #expect(tasks.count == 2)
        #expect(tasks[0].title == "Task 1")
        #expect(tasks[1].title == "Task 2")
    }

    // MARK: - Update Tests

    @Test("Update task title")
    func updateTaskTitle() async throws {
        let store = makeTestStore()
        let task = try store.createTask(title: "Original")

        try store.update(taskID: task.id, title: "Updated")

        let tasks = try store.fetchTasks()
        #expect(tasks.first?.title == "Updated")
    }

    @Test("Update task title without saving")
    func updateTaskTitleWithoutSaving() async throws {
        let store = makeTestStore()
        let task = try store.createTask(title: "Original")

        try store.updateWithoutSaving(taskID: task.id, title: "Updated")

        let tasks = try store.fetchTasks()
        #expect(tasks.first?.title == "Updated")
    }

    @Test("Update with invalid ID does nothing")
    func updateWithInvalidIDDoesNothing() async throws {
        let store = makeTestStore()
        _ = try store.createTask(title: "Task 1")
        let invalidID = UUID()

        try store.update(taskID: invalidID, title: "Should not exist")

        let tasks = try store.fetchTasks()
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Task 1")
    }

    // MARK: - Delete Tests

    @Test("Delete task")
    func deleteTask() async throws {
        let store = makeTestStore()
        let task1 = try store.createTask(title: "Task 1")
        let task2 = try store.createTask(title: "Task 2")

        try store.delete(taskID: task1.id)

        let tasks = try store.fetchTasks()
        #expect(tasks.count == 1)
        #expect(tasks.first?.id == task2.id)
    }

    @Test("Delete all tasks")
    func deleteAllTasks() async throws {
        let store = makeTestStore()
        let task1 = try store.createTask(title: "Task 1")
        let task2 = try store.createTask(title: "Task 2")

        try store.delete(taskID: task1.id)
        try store.delete(taskID: task2.id)

        let tasks = try store.fetchTasks()
        #expect(tasks.isEmpty)
    }

    @Test("Delete with invalid ID does nothing")
    func deleteWithInvalidIDDoesNothing() async throws {
        let store = makeTestStore()
        _ = try store.createTask(title: "Task 1")
        let invalidID = UUID()

        try store.delete(taskID: invalidID)

        let tasks = try store.fetchTasks()
        #expect(tasks.count == 1)
    }

    // MARK: - Edge Cases

    @Test("Task IDs persist across fetches")
    func taskIDsPersistAcrossFetches() async throws {
        let store = makeTestStore()
        let task = try store.createTask(title: "Test")
        let originalID = task.id

        let fetchedTasks = try store.fetchTasks()
        let fetchedID = fetchedTasks.first?.id

        #expect(fetchedID == originalID)
    }

    @Test("Create task increments sortOrder")
    func createTaskIncrementsSortOrder() async throws {
        let store = makeTestStore()

        let task1 = try store.createTask(title: "Task 1")
        let task2 = try store.createTask(title: "Task 2")
        let task3 = try store.createTask(title: "Task 3")

        #expect(task2.sortOrder > task1.sortOrder)
        #expect(task3.sortOrder > task2.sortOrder)
        #expect(task2.sortOrder - task1.sortOrder == 1000)
        #expect(task3.sortOrder - task2.sortOrder == 1000)
    }
}
