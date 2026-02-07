import Foundation
import Testing

@testable import Listless_iOS

@Suite("TaskStore Edge Cases", .serialized)
@MainActor
struct TaskStoreEdgeCaseTests {

    // MARK: - Title Edge Cases

    @Test("Task with empty title")
    func taskWithEmptyTitle() async throws {
        let store = makeTestStore()

        let task = store.createTask(title: "")

        let tasks = store.fetchTasks()
        #expect(tasks.first?.title == "")
    }

    @Test("Task with very long title")
    func taskWithVeryLongTitle() async throws {
        let store = makeTestStore()
        let longTitle = String(repeating: "A", count: 10_000)

        let task = store.createTask(title: longTitle)

        let tasks = store.fetchTasks()
        #expect(tasks.first?.title.count == 10_000)
    }

    @Test("Task with special characters")
    func taskWithSpecialCharacters() async throws {
        let store = makeTestStore()
        let specialTitle = "Test 🎉 with émojis & spëcial çharacters! @#$%^&*()"

        let task = store.createTask(title: specialTitle)

        let tasks = store.fetchTasks()
        #expect(tasks.first?.title == specialTitle)
    }

    @Test("Task with newlines and tabs")
    func taskWithNewlinesAndTabs() async throws {
        let store = makeTestStore()
        let multilineTitle = "Line 1\nLine 2\tTabbed"

        let task = store.createTask(title: multilineTitle)

        let tasks = store.fetchTasks()
        #expect(tasks.first?.title == multilineTitle)
    }

    // MARK: - Large Data Sets

    @Test("Create many tasks")
    func createManyTasks() async throws {
        let store = makeTestStore()
        let count = 100

        for i in 0..<count {
            _ = store.createTask(title: "Task \(i)")
        }

        let tasks = store.fetchTasks()
        #expect(tasks.count == count)
    }

    @Test("Delete all tasks from large set")
    func deleteAllTasksFromLargeSet() async throws {
        let store = makeTestStore()
        var taskIDs: [UUID] = []

        for i in 0..<50 {
            let task = store.createTask(title: "Task \(i)")
            taskIDs.append(task.id)
        }

        for id in taskIDs {
            store.delete(taskID: id)
        }

        let tasks = store.fetchTasks()
        #expect(tasks.isEmpty)
    }

    // MARK: - State Transitions

    @Test("Create task after completing all tasks")
    func createTaskAfterCompletingAllTasks() async throws {
        let (store, taskIDs) = makeTestStoreWithTasks(count: 3)

        for id in taskIDs {
            store.complete(taskID: id)
        }

        let newTask = store.createTask(title: "New task")

        let tasks = store.fetchTasks()
        let activeTasks = tasks.filter { !$0.isCompleted }
        #expect(activeTasks.count == 1)
        #expect(activeTasks[0].id == newTask.id)
    }

    @Test("Rapid updates to same task")
    func rapidUpdatesToSameTask() async throws {
        let store = makeTestStore()
        let task = store.createTask(title: "Original")

        for i in 0..<10 {
            store.update(taskID: task.id, title: "Update \(i)")
        }

        let tasks = store.fetchTasks()
        #expect(tasks.first?.title == "Update 9")
    }

    // MARK: - Store State Tests

    @Test("Store with only completed tasks")
    func storeWithOnlyCompletedTasks() async throws {
        let (store, taskIDs) = makeTestStoreWithTasks(count: 5)

        for id in taskIDs {
            store.complete(taskID: id)
        }

        let tasks = store.fetchTasks()
        #expect(tasks.allSatisfy { $0.isCompleted })
        #expect(tasks.count == 5)
    }

    @Test("SortOrder after completing all tasks")
    func sortOrderAfterCompletingAllTasks() async throws {
        let (store, taskIDs) = makeTestStoreWithTasks(count: 3)

        for id in taskIDs {
            store.complete(taskID: id)
        }

        let newTask1 = store.createTask(title: "New 1")
        let newTask2 = store.createTask(title: "New 2")

        let activeTasks = store.fetchTasks().filter { !$0.isCompleted }
        #expect(activeTasks[0].id == newTask1.id)
        #expect(activeTasks[1].id == newTask2.id)
        #expect(activeTasks[1].sortOrder > activeTasks[0].sortOrder)
    }

    @Test("Uncompleting task moves it back to active")
    func uncompletingTaskMovesItBackToActive() async throws {
        let (store, taskIDs) = makeTestStoreWithTasks(count: 3)
        store.complete(taskID: taskIDs[1])

        store.uncomplete(taskID: taskIDs[1])

        let tasks = store.fetchTasks()
        let activeTasks = tasks.filter { !$0.isCompleted }
        #expect(activeTasks.count == 3)
        #expect(activeTasks.contains { $0.id == taskIDs[1] })
    }
}
