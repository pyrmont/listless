import Foundation
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

@Suite("TaskStore Completion Behavior", .serialized)
@MainActor
struct TaskStoreCompletionTests {

    // MARK: - Basic Completion Tests

    @Test("Complete task")
    func completeTask() async throws {
        let store = makeTestStore()
        let task = try store.createTask(title: "Task to complete")

        try store.complete(taskID: task.id)

        let tasks = try store.fetchTasks()
        #expect(tasks.first?.isCompleted == true)
    }

    @Test("Uncomplete task")
    func uncompleteTask() async throws {
        let store = makeTestStore()
        let task = try store.createTask(title: "Task")
        try store.complete(taskID: task.id)

        try store.uncomplete(taskID: task.id)

        let tasks = try store.fetchTasks()
        #expect(tasks.first?.isCompleted == false)
    }

    @Test("Complete with invalid ID does nothing")
    func completeWithInvalidIDDoesNothing() async throws {
        let store = makeTestStore()
        let task = try store.createTask(title: "Task")
        let invalidID = UUID()

        try store.complete(taskID: invalidID)

        let tasks = try store.fetchTasks()
        #expect(tasks.first?.isCompleted == false)
    }

    @Test("Uncomplete with invalid ID does nothing")
    func uncompleteWithInvalidIDDoesNothing() async throws {
        let store = makeTestStore()
        let task = try store.createTask(title: "Task")
        try store.complete(taskID: task.id)
        let invalidID = UUID()

        try store.uncomplete(taskID: invalidID)

        let tasks = try store.fetchTasks()
        #expect(tasks.first?.isCompleted == true)
    }

    // MARK: - Timestamp Tests

    @Test("Completing task updates timestamp")
    func completingTaskUpdatesTimestamp() async throws {
        let store = makeTestStore()
        let task = try store.createTask(title: "Task")
        let originalUpdatedAt = task.updatedAt

        // Small delay to ensure timestamp difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        try store.complete(taskID: task.id)

        let tasks = try store.fetchTasks()
        let updatedTask = tasks.first
        #expect(updatedTask?.updatedAt ?? Date() > originalUpdatedAt)
    }

    // MARK: - Sorting Tests

    @Test("Active tasks appear before completed tasks")
    func activeTasksAppearBeforeCompletedTasks() async throws {
        let store = makeTestStore()
        let task1 = try store.createTask(title: "Task 1")
        let task2 = try store.createTask(title: "Task 2")
        let task3 = try store.createTask(title: "Task 3")

        try store.complete(taskID: task2.id)

        let tasks = try store.fetchTasks()
        #expect(tasks[0].id == task1.id)
        #expect(tasks[1].id == task3.id)
        #expect(tasks[2].id == task2.id)
    }

    @Test("Completed tasks sorted by completedOrder")
    func completedTasksSortedByCompletedOrder() async throws {
        let store = makeTestStore()
        let task1 = try store.createTask(title: "Task 1")
        let task2 = try store.createTask(title: "Task 2")
        let task3 = try store.createTask(title: "Task 3")

        // Complete in specific order
        try store.complete(taskID: task2.id)
        try store.complete(taskID: task1.id)
        try store.complete(taskID: task3.id)

        let tasks = try store.fetchTasks()
        // All completed, should be sorted by completedOrder (most recently completed first)
        #expect(tasks[0].id == task3.id)
        #expect(tasks[1].id == task1.id)
        #expect(tasks[2].id == task2.id)
    }

    @Test("Toggle completion multiple times")
    func toggleCompletionMultipleTimes() async throws {
        let store = makeTestStore()
        let task = try store.createTask(title: "Task")

        try store.complete(taskID: task.id)
        var tasks = try store.fetchTasks()
        #expect(tasks.first?.isCompleted == true)

        try store.uncomplete(taskID: task.id)
        tasks = try store.fetchTasks()
        #expect(tasks.first?.isCompleted == false)

        try store.complete(taskID: task.id)
        tasks = try store.fetchTasks()
        #expect(tasks.first?.isCompleted == true)
    }

    @Test("Complete all tasks")
    func completeAllTasks() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 5)

        for id in taskIDs {
            try store.complete(taskID: id)
        }

        let tasks = try store.fetchTasks()
        #expect(tasks.allSatisfy { $0.isCompleted })
        #expect(tasks.count == 5)
    }

    @Test("Uncomplete restores previous sortOrder when no active conflict")
    func uncompleteRestoresPreviousSortOrderWhenNoConflict() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 3)
        let taskToRestoreID = taskIDs[1]

        let originalSortOrder = try store.fetchTasks().first { $0.id == taskToRestoreID }?.sortOrder
        #expect(originalSortOrder != nil)

        try store.complete(taskID: taskToRestoreID)
        try store.uncomplete(taskID: taskToRestoreID)

        let activeTasks = try store.fetchTasks().filter { !$0.isCompleted }
        let restoredTask = activeTasks.first { $0.id == taskToRestoreID }

        #expect(restoredTask != nil)
        #expect(restoredTask?.sortOrder == originalSortOrder)
        #expect(activeTasks.count == 3)
    }

    @Test("Uncomplete appends task when restored sortOrder conflicts with active task")
    func uncompleteAppendsWhenRestoredSortOrderConflicts() async throws {
        let store = makeTestStore()
        let activeTask = try store.createTask(title: "Active task")
        let completedTask = try store.createTask(title: "Completed task")

        try store.complete(taskID: completedTask.id)
        try store.moveTask(taskID: activeTask.id, toIndex: 0)
        completedTask.sortOrder = activeTask.sortOrder
        try store.save()

        try store.uncomplete(taskID: completedTask.id)

        let activeTasks = try store.fetchTasks().filter { !$0.isCompleted }
            .sorted { $0.sortOrder < $1.sortOrder }
        let lastActiveTask = activeTasks.last

        #expect(activeTasks.count == 2)
        #expect(lastActiveTask?.id == completedTask.id)
        #expect(lastActiveTask?.sortOrder ?? 0 > activeTask.sortOrder)
    }
}
