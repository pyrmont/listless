import XCTest

final class ListlessMacUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Helpers

    /// The "Click to create" empty state label.
    var emptyStateLabel: XCUIElement {
        app.staticTexts["Click to create"]
    }

    /// The draft row text field that appears after Cmd+N.
    var draftTextField: XCUIElement {
        app.textFields["draft-row-append"]
    }

    /// Returns the text field for a committed task with the given title.
    /// Committed tasks expose as TextField with identifier "task-text-\(title)".
    func taskText(_ title: String) -> XCUIElement {
        app.textFields["task-text-\(title)"]
    }

    /// Creates a task by typing into the draft field and pressing Return.
    /// If no draft field exists yet, presses Cmd+N to create one.
    func createTask(_ title: String) {
        let textField = draftTextField
        if !textField.exists {
            app.typeKey("n", modifierFlags: .command)
            if !textField.waitForExistence(timeout: 2) {
                XCTFail("Draft text field should appear after Cmd+N")
                return
            }
        }
        textField.click()
        textField.typeText(title)
        textField.typeKey(.return, modifierFlags: [])
    }

    /// Returns the Nth checkbox button (0-indexed).
    func taskCheckbox(at index: Int) -> XCUIElement {
        app.buttons.matching(identifier: "task-checkbox").element(boundBy: index)
    }

    /// Enters navigation mode by pressing Escape, then navigates to the task at
    /// the given position (0-indexed from the top) using arrow keys.
    func navigateToTask(at index: Int) {
        app.typeKey(.escape, modifierFlags: [])
        for _ in 0...index {
            app.typeKey(.downArrow, modifierFlags: [])
        }
    }

    // MARK: - Empty State

    func testLaunchShowsEmptyState() {
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "Empty state label should be visible on launch"
        )
    }

    func testEmptyStateDisappearsAfterCreatingTask() {
        createTask("First item")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(emptyStateLabel.exists, "Empty state should disappear after creating a task")
    }

    // MARK: - Task Creation

    func testCreateTaskViaMenuShortcut() {
        createTask("Buy groceries")
        XCTAssertTrue(
            taskText("Buy groceries").waitForExistence(timeout: 2),
            "Task should appear with the typed title"
        )
    }

    func testReturnChainsNewTask() {
        createTask("First item")
        XCTAssertTrue(
            draftTextField.waitForExistence(timeout: 2),
            "New draft text field should appear after Return"
        )
    }

    func testCreateMultipleTasks() {
        createTask("Alpha")
        createTask("Bravo")
        createTask("Charlie")
        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(taskText("Alpha").waitForExistence(timeout: 2))
        XCTAssertTrue(taskText("Bravo").exists)
        XCTAssertTrue(taskText("Charlie").exists)
    }

    func testEmptyTaskDeletedOnCommit() {
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(draftTextField.waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "Empty state should reappear when empty task is discarded"
        )
    }

    // MARK: - Task Completion

    func testCompleteTaskViaCheckbox() {
        createTask("Finish report")
        app.typeKey(.escape, modifierFlags: [])

        let checkbox = taskCheckbox(at: 0)
        XCTAssertTrue(checkbox.waitForExistence(timeout: 2))
        XCTAssertEqual(checkbox.value as? String, "circle")
        checkbox.click()

        let completed = app.buttons.matching(
            NSPredicate(format: "identifier == 'task-checkbox' AND value == 'checkmark.circle.fill'")
        ).firstMatch
        XCTAssertTrue(
            completed.waitForExistence(timeout: 3),
            "Checkbox should show checkmark after clicking"
        )
    }

    func testUncompleteTask() {
        createTask("Finish report")
        app.typeKey(.escape, modifierFlags: [])

        taskCheckbox(at: 0).click()

        let completed = app.buttons.matching(
            NSPredicate(format: "identifier == 'task-checkbox' AND value == 'checkmark.circle.fill'")
        ).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 3))
        completed.click()

        let uncompleted = app.buttons.matching(
            NSPredicate(format: "identifier == 'task-checkbox' AND value == 'circle'")
        ).firstMatch
        XCTAssertTrue(
            uncompleted.waitForExistence(timeout: 3),
            "Checkbox should revert to circle after uncompleting"
        )
    }

    // MARK: - Task Deletion

    func testDeleteTaskViaBackspace() {
        createTask("Delete me")
        navigateToTask(at: 0)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "Empty state should reappear after deleting the only task"
        )
    }

    func testArrowKeyNavigationThenDelete() {
        createTask("Keep me")
        createTask("Delete me")
        navigateToTask(at: 1)
        app.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(taskText("Keep me").waitForExistence(timeout: 2), "First task should remain")
        XCTAssertFalse(taskText("Delete me").exists, "Second task should be deleted")
    }

    // MARK: - Reordering

    func testMoveTaskUp() {
        createTask("Alpha")
        createTask("Bravo")
        navigateToTask(at: 1)
        app.typeKey(.upArrow, modifierFlags: .command)

        // Use firstMatch to avoid ambiguity if draft row duplicates an identifier
        let bravo = app.textFields.matching(identifier: "task-text-Bravo").firstMatch
        let alpha = app.textFields.matching(identifier: "task-text-Alpha").firstMatch
        XCTAssertTrue(bravo.waitForExistence(timeout: 2))
        XCTAssertTrue(alpha.exists)
        XCTAssertLessThan(
            bravo.frame.minY, alpha.frame.minY,
            "Bravo should appear above Alpha after moving up"
        )
    }

    func testMoveTaskDown() {
        createTask("Alpha")
        createTask("Bravo")
        navigateToTask(at: 0)
        app.typeKey(.downArrow, modifierFlags: .command)

        let alpha = app.textFields.matching(identifier: "task-text-Alpha").firstMatch
        let bravo = app.textFields.matching(identifier: "task-text-Bravo").firstMatch
        XCTAssertTrue(alpha.waitForExistence(timeout: 2))
        XCTAssertTrue(bravo.exists)
        XCTAssertGreaterThan(
            alpha.frame.minY, bravo.frame.minY,
            "Alpha should appear below Bravo after moving down"
        )
    }

    // MARK: - Clear Completed

    func testClearCompleted() {
        createTask("Done task")
        app.typeKey(.escape, modifierFlags: [])

        taskCheckbox(at: 0).click()

        let completed = app.buttons.matching(
            NSPredicate(format: "identifier == 'task-checkbox' AND value == 'checkmark.circle.fill'")
        ).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 3))

        app.menuBars.menuBarItems["Edit"].click()
        app.menuBars.menuBarItems["Edit"].menus.menuItems["Clear Completed"].click()

        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 3),
            "Empty state should reappear after clearing the only completed task"
        )
    }
}
