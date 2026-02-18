import Foundation
import Testing

@testable import Listless_iOS

@Suite("TaskStore Task Reordering", .serialized)
@MainActor
struct TaskStoreOrderingTests {

    // MARK: - Initial State Tests

    @Test("Initial sortOrder has 1000-point gaps")
    func initialSortOrderHasThousandPointGaps() async throws {
        let store = makeTestStore()

        let task1 = try store.createTask(title: "Task 1")
        let task2 = try store.createTask(title: "Task 2")
        let task3 = try store.createTask(title: "Task 3")

        let tasks = try store.fetchTasks()

        // All tasks are active, so they should be the first 3
        #expect(tasks.count == 3)

        // Verify tasks are in ascending order
        #expect(tasks[0].sortOrder < tasks[1].sortOrder)
        #expect(tasks[1].sortOrder < tasks[2].sortOrder)

        // Verify 1000-point gaps between tasks
        #expect(tasks[1].sortOrder - tasks[0].sortOrder == 1000)
        #expect(tasks[2].sortOrder - tasks[1].sortOrder == 1000)
    }

    // MARK: - Move Tests (Parameterized)

    @Test("Move task to different positions", arguments: [
        (from: 0, to: 2),
        (from: 2, to: 0),
        (from: 0, to: 1),
        (from: 1, to: 0),
        (from: 1, to: 2),
        (from: 2, to: 1),
    ])
    func moveTaskToDifferentPositions(from: Int, to: Int) async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 3)
        let taskToMove = taskIDs[from]

        try store.moveTask(taskID: taskToMove, toIndex: to)

        let tasks = try store.fetchTasks().filter { !$0.isCompleted }
        #expect(tasks[to].id == taskToMove)
    }

    // MARK: - Order Preservation Tests

    @Test("Moving maintains 1000-point gaps")
    func movingMaintainsThousandPointGaps() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 4)

        try store.moveTask(taskID: taskIDs[0], toIndex: 2)

        let tasks = try store.fetchTasks().filter { !$0.isCompleted }
        #expect(tasks[0].sortOrder == 0)
        #expect(tasks[1].sortOrder == 1000)
        #expect(tasks[2].sortOrder == 2000)
        #expect(tasks[3].sortOrder == 3000)
    }

    @Test("Move task to same index does nothing")
    func moveTaskToSameIndexDoesNothing() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 3)
        let originalTasks = try store.fetchTasks().filter { !$0.isCompleted }

        try store.moveTask(taskID: taskIDs[1], toIndex: 1)

        let tasks = try store.fetchTasks().filter { !$0.isCompleted }
        #expect(tasks[0].id == originalTasks[0].id)
        #expect(tasks[1].id == originalTasks[1].id)
        #expect(tasks[2].id == originalTasks[2].id)
    }

    // MARK: - Invalid Input Tests

    @Test("Move with invalid ID does nothing")
    func moveWithInvalidIDDoesNothing() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 3)
        let originalTasks = try store.fetchTasks().filter { !$0.isCompleted }
        let invalidID = UUID()

        try store.moveTask(taskID: invalidID, toIndex: 0)

        let tasks = try store.fetchTasks().filter { !$0.isCompleted }
        #expect(tasks[0].id == originalTasks[0].id)
        #expect(tasks[1].id == originalTasks[1].id)
        #expect(tasks[2].id == originalTasks[2].id)
    }

    @Test("Move to negative index clamps to 0")
    func moveToNegativeIndexClampsToZero() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 3)

        try store.moveTask(taskID: taskIDs[2], toIndex: -5)

        let tasks = try store.fetchTasks().filter { !$0.isCompleted }
        #expect(tasks[0].id == taskIDs[2])
    }

    @Test("Move to out-of-bounds index clamps to end")
    func moveToOutOfBoundsIndexClampsToEnd() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 3)

        try store.moveTask(taskID: taskIDs[0], toIndex: 999)

        let tasks = try store.fetchTasks().filter { !$0.isCompleted }
        #expect(tasks[2].id == taskIDs[0])
    }

    // MARK: - Completed Task Tests

    @Test("Moving only affects active tasks")
    func movingOnlyAffectsActiveTasks() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 4)
        try store.complete(taskID: taskIDs[3])

        try store.moveTask(taskID: taskIDs[0], toIndex: 2)

        let allTasks = try store.fetchTasks()
        let activeTasks = allTasks.filter { !$0.isCompleted }
        let completedTasks = allTasks.filter { $0.isCompleted }

        #expect(activeTasks.count == 3)
        #expect(completedTasks.count == 1)
        #expect(completedTasks[0].id == taskIDs[3])
    }

    @Test("Moving completed task does nothing")
    func movingCompletedTaskDoesNothing() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 3)
        try store.complete(taskID: taskIDs[0])
        let originalTasks = try store.fetchTasks()

        try store.moveTask(taskID: taskIDs[0], toIndex: 1)

        let tasks = try store.fetchTasks()
        #expect(tasks[0].id == originalTasks[0].id)
        #expect(tasks[1].id == originalTasks[1].id)
        #expect(tasks[2].id == originalTasks[2].id)
    }

    // MARK: - Edge Cases

    @Test("Move single task does nothing")
    func moveSingleTaskDoesNothing() async throws {
        let store = makeTestStore()
        let task = try store.createTask(title: "Only task")

        try store.moveTask(taskID: task.id, toIndex: 0)

        let tasks = try store.fetchTasks()
        #expect(tasks.count == 1)
        #expect(tasks[0].id == task.id)
    }

    @Test("Move in empty store does nothing")
    func moveInEmptyStoreDoesNothing() async throws {
        let store = makeTestStore()
        let randomID = UUID()

        try store.moveTask(taskID: randomID, toIndex: 0)

        let tasks = try store.fetchTasks()
        #expect(tasks.isEmpty)
    }

    @Test("Multiple moves maintain order")
    func multipleMoveMaintainOrder() async throws {
        let (store, taskIDs) = try makeTestStoreWithTasks(count: 4)

        try store.moveTask(taskID: taskIDs[0], toIndex: 3)
        try store.moveTask(taskID: taskIDs[2], toIndex: 0)

        let tasks = try store.fetchTasks().filter { !$0.isCompleted }
        #expect(tasks[0].id == taskIDs[2])
        #expect(tasks[3].id == taskIDs[0])
    }
}
