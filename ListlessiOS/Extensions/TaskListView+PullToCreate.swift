import SwiftUI

extension TaskListView {

    // MARK: - Phantom Entry Row Helpers

    /// Show the phantom row and focus its text field.
    func revealPhantomRow() -> UUID {
        phantomTitle = ""
        phantomRowVisible = true
        pendingFocus = .task(Self.phantomRowID)
        focusedField = .task(Self.phantomRowID)
        selectedTaskID = Self.phantomRowID
        return Self.phantomRowID
    }

    /// Commit the phantom row: create a real task if the user typed something,
    /// then hide the phantom and reset its state.
    func commitPhantomRow() {
        let title = phantomTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let collapse: () -> Void = {
            phantomRowVisible = false
            phantomTitle = ""
            selectedTaskID = nil
            var state = pullToCreate
            state.isInsertionPending = false
            state.indicatorOffset = 0
            pullToCreate = state
        }

        if title.isEmpty {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.95)) {
                collapse()
            }
        } else {
            // Keep the successful create swap immediate so focus can move
            // straight into the real task row without a visible intermediate state.
            var t = Transaction(animation: nil)
            t.disablesAnimations = true
            withTransaction(t) {
                collapse()
            }
        }

        focusedField = nil

        guard !title.isEmpty else { return }

        do {
            let task = try store.createTask(title: title, atBeginning: true)
            try store.save()
            selectedTaskID = task.id
        } catch {
            presentStoreError(error)
        }
    }
}
