import Foundation
import Testing

@testable import Listless_iOS

/// Creates a fresh TaskStore with in-memory persistence for isolated testing.
@MainActor
func makeTestStore() -> TaskStore {
    let controller = PersistenceController(inMemory: true)
    return TaskStore(persistenceController: controller)
}

/// Creates a TaskStore pre-populated with test tasks.
/// - Parameters:
///   - count: Number of tasks to create (default: 3)
///   - titles: Optional array of titles; if nil, generates "Task 1", "Task 2", etc.
/// - Returns: Tuple of (store, array of created task IDs)
@MainActor
func makeTestStoreWithTasks(count: Int = 3, titles: [String]? = nil) -> (TaskStore, [UUID]) {
    let store = makeTestStore()
    var taskIDs: [UUID] = []

    for i in 0..<count {
        let title = titles?[safe: i] ?? "Task \(i + 1)"
        let task = store.createTask(title: title)
        taskIDs.append(task.id)
    }

    return (store, taskIDs)
}

/// Safe array subscript that returns nil instead of crashing on out-of-bounds access.
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
