import SwiftUI

// MARK: - Task Actions

struct TaskActions {
    var newTask: (() -> Void)?
    var deleteTask: (() -> Void)?
    var moveUp: (() -> Void)?
    var moveDown: (() -> Void)?
    var markCompleted: (() -> Void)?
}

// MARK: - Focused Value Key

struct TaskActionsKey: FocusedValueKey {
    typealias Value = TaskActions
}

extension FocusedValues {
    var taskActions: TaskActions? {
        get { self[TaskActionsKey.self] }
        set { self[TaskActionsKey.self] = newValue }
    }
}

// MARK: - Commands

struct TaskCommands: Commands {
    @FocusedValue(\.taskActions) var actions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Task") {
                actions?.newTask?()
            }
            .keyboardShortcut("n")
            .disabled(actions?.newTask == nil)
        }

        CommandGroup(replacing: .textEditing) {
            Button("Delete") {
                actions?.deleteTask?()
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(actions?.deleteTask == nil)

            Divider()

            Button("Move Up") {
                actions?.moveUp?()
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
            .disabled(actions?.moveUp == nil)

            Button("Move Down") {
                actions?.moveDown?()
            }
            .keyboardShortcut(.downArrow, modifiers: .command)
            .disabled(actions?.moveDown == nil)

            Button("Mark as Complete") {
                actions?.markCompleted?()
            }
            .keyboardShortcut(.space, modifiers: .command)
            .disabled(actions?.markCompleted == nil)
        }
    }
}
