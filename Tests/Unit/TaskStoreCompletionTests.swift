import Foundation
import Testing

@testable import Listless_iOS

@Suite("TaskStore Completion Behavior", .serialized)
@MainActor
struct TaskStoreCompletionTests {

    // MARK: - Basic Completion Tests

    @Test("Complete task")
    func completeTask() async throws {
        let store = makeTestStore()
        let task = store.createTask(title: "Task to complete")

        store.complete(taskID: task.id)

        let tasks = store.fetchTasks()
        #expect(tasks.first?.isCompleted == true)
    }

    @Test("Uncomplete task")
    func uncompleteTask() async throws {
        let store = makeTestStore()
        let task = store.createTask(title: "Task")
        store.complete(taskID: task.id)

        store.uncomplete(taskID: task.id)

        let tasks = store.fetchTasks()
        #expect(tasks.first?.isCompleted == false)
    }

    @Test("Complete with invalid ID does nothing")
    func completeWithInvalidIDDoesNothing() async throws {
        let store = makeTestStore()
        let task = store.createTask(title: "Task")
        let invalidID = UUID()

        store.complete(taskID: invalidID)

        let tasks = store.fetchTasks()
        #expect(tasks.first?.isCompleted == false)
    }

    @Test("Uncomplete with invalid ID does nothing")
    func uncompleteWithInvalidIDDoesNothing() async throws {
        let store = makeTestStore()
        let task = store.createTask(title: "Task")
        store.complete(taskID: task.id)
        let invalidID = UUID()

        store.uncomplete(taskID: invalidID)

        let tasks = store.fetchTasks()
        #expect(tasks.first?.isCompleted == true)
    }

    // MARK: - Timestamp Tests

    @Test("Completing task updates timestamp")
    func completingTaskUpdatesTimestamp() async throws {
        let store = makeTestStore()
        let task = store.createTask(title: "Task")
        let originalUpdatedAt = task.updatedAt

        // Small delay to ensure timestamp difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        store.complete(taskID: task.id)

        let tasks = store.fetchTasks()
        let updatedTask = tasks.first
        #expect(updatedTask?.updatedAt ?? Date() > originalUpdatedAt)
    }

    // MARK: - Sorting Tests

    @Test("Active tasks appear before completed tasks")
    func activeTasksAppearBeforeCompletedTasks() async throws {
        let store = makeTestStore()
        let task1 = store.createTask(title: "Task 1")
        let task2 = store.createTask(title: "Task 2")
        let task3 = store.createTask(title: "Task 3")

        store.complete(taskID: task2.id)

        let tasks = store.fetchTasks()
        #expect(tasks[0].id == task1.id)
        #expect(tasks[1].id == task3.id)
        #expect(tasks[2].id == task2.id)
    }

    @Test("Completed tasks sorted by updatedAt")
    func completedTasksSortedByUpdatedAt() async throws {
        let store = makeTestStore()
        let task1 = store.createTask(title: "Task 1")
        let task2 = store.createTask(title: "Task 2")
        let task3 = store.createTask(title: "Task 3")

        // Complete in specific order with delays
        store.complete(taskID: task2.id)
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        store.complete(taskID: task1.id)
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        store.complete(taskID: task3.id)

        let tasks = store.fetchTasks()
        // All completed, should be sorted by updatedAt (completion order)
        #expect(tasks[0].id == task2.id)
        #expect(tasks[1].id == task1.id)
        #expect(tasks[2].id == task3.id)
    }

    @Test("Toggle completion multiple times")
    func toggleCompletionMultipleTimes() async throws {
        let store = makeTestStore()
        let task = store.createTask(title: "Task")

        store.complete(taskID: task.id)
        var tasks = store.fetchTasks()
        #expect(tasks.first?.isCompleted == true)

        store.uncomplete(taskID: task.id)
        tasks = store.fetchTasks()
        #expect(tasks.first?.isCompleted == false)

        store.complete(taskID: task.id)
        tasks = store.fetchTasks()
        #expect(tasks.first?.isCompleted == true)
    }

    @Test("Complete all tasks")
    func completeAllTasks() async throws {
        let (store, taskIDs) = makeTestStoreWithTasks(count: 5)

        for id in taskIDs {
            store.complete(taskID: id)
        }

        let tasks = store.fetchTasks()
        #expect(tasks.allSatisfy { $0.isCompleted })
        #expect(tasks.count == 5)
    }
}
