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

    @Test("Uncomplete restores previous sortOrder when no active conflict")
    func uncompleteRestoresPreviousSortOrderWhenNoConflict() async throws {
        let (store, taskIDs) = makeTestStoreWithTasks(count: 3)
        let taskToRestoreID = taskIDs[1]

        let originalSortOrder = store.fetchTasks().first { $0.id == taskToRestoreID }?.sortOrder
        #expect(originalSortOrder != nil)

        store.complete(taskID: taskToRestoreID)
        store.uncomplete(taskID: taskToRestoreID)

        let activeTasks = store.fetchTasks().filter { !$0.isCompleted }
        let restoredTask = activeTasks.first { $0.id == taskToRestoreID }

        #expect(restoredTask != nil)
        #expect(restoredTask?.sortOrder == originalSortOrder)
        #expect(activeTasks.count == 3)
    }

    @Test("Uncomplete appends task when restored sortOrder conflicts with active task")
    func uncompleteAppendsWhenRestoredSortOrderConflicts() async throws {
        let store = makeTestStore()
        let activeTask = store.createTask(title: "Active task")
        let completedTask = store.createTask(title: "Completed task")

        store.complete(taskID: completedTask.id)
        store.moveTask(taskID: activeTask.id, toIndex: 0)
        completedTask.sortOrder = activeTask.sortOrder
        store.save()

        store.uncomplete(taskID: completedTask.id)

        let activeTasks = store.fetchTasks().filter { !$0.isCompleted }
            .sorted { $0.sortOrder < $1.sortOrder }
        let lastActiveTask = activeTasks.last

        #expect(activeTasks.count == 2)
        #expect(lastActiveTask?.id == completedTask.id)
        #expect(lastActiveTask?.sortOrder ?? 0 > activeTask.sortOrder)
    }
}
