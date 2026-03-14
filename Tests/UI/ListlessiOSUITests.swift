import XCTest

final class ListlessiOSUITests: XCTestCase {
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

    /// The "Pull down to create" empty state label.
    var emptyStateLabel: XCUIElement {
        app.staticTexts["Pull down to create"]
    }

    /// The main scroll view area; tapping empty space here creates a draft task.
    var taskListScrollView: XCUIElement {
        app.scrollViews["task-list-scrollview"]
    }

    /// The draft row text view that appears after tapping empty space.
    /// TappableTextField wraps UITextView, so XCUITest sees it as a textView.
    var draftTextField: XCUIElement {
        app.textViews.matching(identifier: "draft-row-append").firstMatch
    }

    /// Returns the text view for a committed task with the given title.
    func taskText(_ title: String) -> XCUIElement {
        app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH 'task-text-' AND value == %@", title)
        ).firstMatch
    }

    /// Creates a task by tapping empty space to reveal the draft field,
    /// typing a title, and pressing Return.
    func createTask(_ title: String) {
        let textView = draftTextField
        if !textView.exists {
            taskListScrollView.tap()
            if !textView.waitForExistence(timeout: 2) {
                XCTFail("Draft text view should appear after tapping empty space")
                return
            }
        }
        textView.tap()
        textView.typeText(title + "\n")
    }

    /// Returns the Nth checkbox button (0-indexed).
    func taskCheckbox(at index: Int) -> XCUIElement {
        app.buttons.matching(identifier: "task-checkbox").element(boundBy: index)
    }

    /// Exits editing mode. After createTask, the new draft text view is
    /// focused. Dismiss it by tapping the scroll view background (which
    /// calls handleBackgroundTap to commit/dismiss the empty draft).
    func exitEditingMode() {
        let draft = draftTextField
        if draft.exists {
            draft.typeText("\n")
        }
        // Tap background to deselect
        taskListScrollView.tap()
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
        exitEditingMode()
        XCTAssertFalse(emptyStateLabel.exists, "Empty state should disappear after creating a task")
    }

    // MARK: - Task Creation

    func testCreateTaskViaTap() {
        createTask("Buy groceries")
        exitEditingMode()
        XCTAssertTrue(
            taskText("Buy groceries").waitForExistence(timeout: 2),
            "Task should appear with the typed title"
        )
    }

    func testReturnChainsNewTask() {
        createTask("First item")
        XCTAssertTrue(
            draftTextField.waitForExistence(timeout: 2),
            "New draft text view should appear after Return"
        )
    }

    func testCreateMultipleTasks() {
        createTask("Alpha")
        createTask("Bravo")
        createTask("Charlie")
        exitEditingMode()

        XCTAssertTrue(taskText("Alpha").waitForExistence(timeout: 2))
        XCTAssertTrue(taskText("Bravo").exists)
        XCTAssertTrue(taskText("Charlie").exists)
    }

    func testEmptyTaskDeletedOnCommit() {
        taskListScrollView.tap()
        XCTAssertTrue(draftTextField.waitForExistence(timeout: 2))
        draftTextField.typeText("\n")
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "Empty state should reappear when empty task is discarded"
        )
    }

    // MARK: - Task Completion

    func testCompleteTaskViaCheckbox() {
        createTask("Finish report")
        exitEditingMode()

        let checkbox = taskCheckbox(at: 0)
        XCTAssertTrue(checkbox.waitForExistence(timeout: 2))
        XCTAssertEqual(checkbox.value as? String, "circle")
        checkbox.tap()

        let completed = app.buttons.matching(
            NSPredicate(format: "identifier == 'task-checkbox' AND value == 'checkmark.circle.fill'")
        ).firstMatch
        XCTAssertTrue(
            completed.waitForExistence(timeout: 3),
            "Checkbox should show checkmark after tapping"
        )
    }

    func testUncompleteTask() {
        createTask("Finish report")
        exitEditingMode()

        taskCheckbox(at: 0).tap()

        let completed = app.buttons.matching(
            NSPredicate(format: "identifier == 'task-checkbox' AND value == 'checkmark.circle.fill'")
        ).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 3))
        completed.tap()

        let uncompleted = app.buttons.matching(
            NSPredicate(format: "identifier == 'task-checkbox' AND value == 'circle'")
        ).firstMatch
        XCTAssertTrue(
            uncompleted.waitForExistence(timeout: 3),
            "Checkbox should revert to circle after uncompleting"
        )
    }
}
