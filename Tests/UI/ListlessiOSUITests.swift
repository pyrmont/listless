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

    /// The main scroll view area; tapping empty space here creates a draft item.
    var itemListScrollView: XCUIElement {
        app.scrollViews["item-list-scrollview"]
    }

    /// The draft row text view that appears after tapping empty space.
    /// TappableTextField wraps UITextView, so XCUITest sees it as a textView.
    var draftTextField: XCUIElement {
        app.textViews.matching(identifier: "draft-row-append").firstMatch
    }

    /// Returns the static text for a committed item with the given title.
    func itemText(_ title: String) -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'item-text-' AND label == %@", title)
        ).firstMatch
    }

    /// Creates a item by tapping empty space to reveal the draft field,
    /// typing a title, and pressing Return.
    func createItem(_ title: String) {
        let textView = draftTextField
        if !textView.exists {
            itemListScrollView.tap()
            if !textView.waitForExistence(timeout: 2) {
                XCTFail("Draft text view should appear after tapping empty space")
                return
            }
        }
        textView.tap()
        textView.typeText(title + "\n")
    }

    /// Returns the Nth checkbox button (0-indexed).
    func itemCheckbox(at index: Int) -> XCUIElement {
        app.buttons.matching(identifier: "item-checkbox").element(boundBy: index)
    }

    /// Exits editing mode. After createItem, the new draft text view is
    /// focused. Dismiss it by tapping the scroll view background (which
    /// calls handleBackgroundTap to commit/dismiss the empty draft).
    func exitEditingMode() {
        let draft = draftTextField
        if draft.exists {
            draft.typeText("\n")
        }
        // Tap background to deselect
        itemListScrollView.tap()
    }

    // MARK: - Empty State

    func testLaunchShowsEmptyState() {
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "Empty state label should be visible on launch"
        )
    }

    func testEmptyStateDisappearsAfterCreatingItem() {
        createItem("First item")
        exitEditingMode()
        XCTAssertFalse(emptyStateLabel.exists, "Empty state should disappear after creating a item")
    }

    // MARK: - Item Creation

    func testCreateItemViaTap() {
        createItem("Buy groceries")
        exitEditingMode()
        XCTAssertTrue(
            itemText("Buy groceries").waitForExistence(timeout: 2),
            "Item should appear with the typed title"
        )
    }

    func testReturnChainsNewItem() {
        createItem("First item")
        XCTAssertTrue(
            draftTextField.waitForExistence(timeout: 2),
            "New draft text view should appear after Return"
        )
    }

    func testCreateMultipleItems() {
        createItem("Alpha")
        createItem("Bravo")
        createItem("Charlie")
        exitEditingMode()

        XCTAssertTrue(itemText("Alpha").waitForExistence(timeout: 2))
        XCTAssertTrue(itemText("Bravo").exists)
        XCTAssertTrue(itemText("Charlie").exists)
    }

    func testEmptyItemDeletedOnCommit() {
        itemListScrollView.tap()
        XCTAssertTrue(draftTextField.waitForExistence(timeout: 2))
        draftTextField.typeText("\n")
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "Empty state should reappear when empty item is discarded"
        )
    }

    // MARK: - Item Completion

    func testCompleteItemViaCheckbox() {
        createItem("Finish report")
        exitEditingMode()

        let checkbox = itemCheckbox(at: 0)
        XCTAssertTrue(checkbox.waitForExistence(timeout: 2))
        XCTAssertEqual(checkbox.value as? String, "circle")
        checkbox.tap()

        let completed = app.buttons.matching(
            NSPredicate(format: "identifier == 'item-checkbox' AND value == 'checkmark.circle.fill'")
        ).firstMatch
        XCTAssertTrue(
            completed.waitForExistence(timeout: 3),
            "Checkbox should show checkmark after tapping"
        )
    }

    func testUncompleteItem() {
        createItem("Finish report")
        exitEditingMode()

        itemCheckbox(at: 0).tap()

        let completed = app.buttons.matching(
            NSPredicate(format: "identifier == 'item-checkbox' AND value == 'checkmark.circle.fill'")
        ).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 3))
        completed.tap()

        let uncompleted = app.buttons.matching(
            NSPredicate(format: "identifier == 'item-checkbox' AND value == 'circle'")
        ).firstMatch
        XCTAssertTrue(
            uncompleted.waitForExistence(timeout: 3),
            "Checkbox should revert to circle after uncompleting"
        )
    }
}
