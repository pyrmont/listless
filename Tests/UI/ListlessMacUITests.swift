import CoreGraphics
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

    /// Returns the text field for a committed item with the given title.
    func itemText(_ title: String) -> XCUIElement {
        app.textFields.matching(
            NSPredicate(format: "identifier BEGINSWITH 'item-text-' AND value == %@", title)
        ).firstMatch
    }

    /// Creates a item by typing into the draft field and pressing Return.
    /// If no draft field exists yet, presses Cmd+N to create one.
    func createItem(_ title: String) {
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
    func itemCheckbox(at index: Int) -> XCUIElement {
        app.buttons.matching(identifier: "item-checkbox").element(boundBy: index)
    }

    /// Enters navigation mode by pressing Escape, then navigates to the item at
    /// the given position (0-indexed from the top) using arrow keys.
    func navigateToItem(at index: Int) {
        app.typeKey(.escape, modifierFlags: [])
        for _ in 0...index {
            app.typeKey(.downArrow, modifierFlags: [])
        }
    }

    /// Performs a Command+Click on the row containing the given item title.
    /// Uses CGEvent mouse events with `.maskCommand` so the app sees the
    /// modifier via `NSApp.currentEvent?.modifierFlags`. Clicks in the
    /// row's left padding area (before the checkbox) so the tap gesture
    /// fires rather than the text field or checkbox.
    func cmdClickRow(withText title: String) {
        let textField = itemText(title)
        XCTAssertTrue(textField.waitForExistence(timeout: 2))
        // Offset to the left of the text field, into the row's 16pt left padding.
        let coord = textField.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: -40, dy: 0))
        let point = coord.screenPoint

        let src = CGEventSource(stateID: .combinedSessionState)

        let mouseDown = CGEvent(
            mouseEventSource: src, mouseType: .leftMouseDown,
            mouseCursorPosition: point, mouseButton: .left
        )!
        mouseDown.flags = .maskCommand
        mouseDown.post(tap: .cgSessionEventTap)
        usleep(50_000)

        let mouseUp = CGEvent(
            mouseEventSource: src, mouseType: .leftMouseUp,
            mouseCursorPosition: point, mouseButton: .left
        )!
        mouseUp.flags = .maskCommand
        mouseUp.post(tap: .cgSessionEventTap)
        usleep(200_000)
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
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(emptyStateLabel.exists, "Empty state should disappear after creating a item")
    }

    // MARK: - Item Creation

    func testCmdNFocusesDraftField() {
        app.typeKey("n", modifierFlags: .command)
        let textField = draftTextField
        XCTAssertTrue(
            textField.waitForExistence(timeout: 2),
            "Draft text field should appear after Cmd+N"
        )
        // Type directly without clicking — verifies the field has focus
        textField.typeText("Focused item")
        textField.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            itemText("Focused item").waitForExistence(timeout: 2),
            "Typing without clicking should commit the item if draft field has focus"
        )
    }

    func testCreateItemViaMenuShortcut() {
        createItem("Buy groceries")
        XCTAssertTrue(
            itemText("Buy groceries").waitForExistence(timeout: 2),
            "Item should appear with the typed title"
        )
    }

    func testReturnChainsNewItem() {
        createItem("First item")
        XCTAssertTrue(
            draftTextField.waitForExistence(timeout: 2),
            "New draft text field should appear after Return"
        )
    }

    func testCreateMultipleItems() {
        createItem("Alpha")
        createItem("Bravo")
        createItem("Charlie")
        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(itemText("Alpha").waitForExistence(timeout: 2))
        XCTAssertTrue(itemText("Bravo").exists)
        XCTAssertTrue(itemText("Charlie").exists)
    }

    func testEmptyItemDeletedOnCommit() {
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(draftTextField.waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "Empty state should reappear when empty item is discarded"
        )
    }

    // MARK: - Item Completion

    func testCompleteItemViaCheckbox() {
        createItem("Finish report")
        app.typeKey(.escape, modifierFlags: [])

        let checkbox = itemCheckbox(at: 0)
        XCTAssertTrue(checkbox.waitForExistence(timeout: 2))
        XCTAssertEqual(checkbox.value as? String, "circle")
        checkbox.click()

        let completed = app.buttons.matching(
            NSPredicate(format: "identifier == 'item-checkbox' AND value == 'checkmark.circle.fill'")
        ).firstMatch
        XCTAssertTrue(
            completed.waitForExistence(timeout: 3),
            "Checkbox should show checkmark after clicking"
        )
    }

    func testUncompleteItem() {
        createItem("Finish report")
        app.typeKey(.escape, modifierFlags: [])

        itemCheckbox(at: 0).click()

        let completed = app.buttons.matching(
            NSPredicate(format: "identifier == 'item-checkbox' AND value == 'checkmark.circle.fill'")
        ).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 3))
        completed.click()

        let uncompleted = app.buttons.matching(
            NSPredicate(format: "identifier == 'item-checkbox' AND value == 'circle'")
        ).firstMatch
        XCTAssertTrue(
            uncompleted.waitForExistence(timeout: 3),
            "Checkbox should revert to circle after uncompleting"
        )
    }

    // MARK: - Item Deletion

    func testDeleteItemViaBackspace() {
        createItem("Delete me")
        navigateToItem(at: 0)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "Empty state should reappear after deleting the only item"
        )
    }

    func testArrowKeyNavigationThenDelete() {
        createItem("Keep me")
        createItem("Delete me")
        navigateToItem(at: 1)
        app.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(itemText("Keep me").waitForExistence(timeout: 2), "First item should remain")
        XCTAssertFalse(itemText("Delete me").exists, "Second item should be deleted")
    }

    // MARK: - Reordering

    func testMoveItemUp() {
        createItem("Alpha")
        createItem("Bravo")
        navigateToItem(at: 1)
        app.typeKey(.upArrow, modifierFlags: .command)

        let bravo = itemText("Bravo")
        let alpha = itemText("Alpha")
        XCTAssertTrue(bravo.waitForExistence(timeout: 2))
        XCTAssertTrue(alpha.exists)
        XCTAssertLessThan(
            bravo.frame.minY, alpha.frame.minY,
            "Bravo should appear above Alpha after moving up"
        )
    }

    func testMoveItemDown() {
        createItem("Alpha")
        createItem("Bravo")
        navigateToItem(at: 0)
        app.typeKey(.downArrow, modifierFlags: .command)

        let alpha = itemText("Alpha")
        let bravo = itemText("Bravo")
        XCTAssertTrue(alpha.waitForExistence(timeout: 2))
        XCTAssertTrue(bravo.exists)
        XCTAssertGreaterThan(
            alpha.frame.minY, bravo.frame.minY,
            "Alpha should appear below Bravo after moving down"
        )
    }

    // MARK: - Select All

    func testSelectAllThenDelete() {
        createItem("Alpha")
        createItem("Bravo")
        createItem("Charlie")
        navigateToItem(at: 0)
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "All items should be deleted after Select All + Delete"
        )
    }

    func testSelectAllIncludesCompletedItems() {
        createItem("Active item")
        createItem("Done item")
        app.typeKey(.escape, modifierFlags: [])

        // Complete the second item
        itemCheckbox(at: 1).click()
        let completed = app.buttons.matching(
            NSPredicate(format: "identifier == 'item-checkbox' AND value == 'checkmark.circle.fill'")
        ).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 3))

        // Navigate to first item, then select all and delete
        navigateToItem(at: 0)
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "Both active and completed items should be deleted after Select All + Delete"
        )
    }

    // MARK: - Clear Completed

    func testClearCompleted() {
        createItem("Done item")
        app.typeKey(.escape, modifierFlags: [])

        itemCheckbox(at: 0).click()

        let completed = app.buttons.matching(
            NSPredicate(format: "identifier == 'item-checkbox' AND value == 'checkmark.circle.fill'")
        ).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 3))

        app.menuBars.menuBarItems["Edit"].click()
        app.menuBars.menuBarItems["Edit"].menus.menuItems["Clear Completed"].click()

        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 3),
            "Empty state should reappear after clearing the only completed item"
        )
    }

    // MARK: - Shift+Arrow Selection

    func testShiftDownExtendsSelection() {
        createItem("Alpha")
        createItem("Bravo")
        createItem("Charlie")
        navigateToItem(at: 0)
        app.typeKey(.downArrow, modifierFlags: .shift)
        app.typeKey(.downArrow, modifierFlags: .shift)
        // All three should be selected; delete removes them all.
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "All three items should be deleted after Shift+Down range select"
        )
    }

    func testShiftUpContractsSelection() {
        createItem("Alpha")
        createItem("Bravo")
        createItem("Charlie")
        navigateToItem(at: 0)
        // Extend down to select Alpha, Bravo, Charlie
        app.typeKey(.downArrow, modifierFlags: .shift)
        app.typeKey(.downArrow, modifierFlags: .shift)
        // Contract back up: deselect Charlie, then Bravo
        app.typeKey(.upArrow, modifierFlags: .shift)
        app.typeKey(.upArrow, modifierFlags: .shift)
        // Only Alpha should be selected now.
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(itemText("Bravo").waitForExistence(timeout: 2), "Bravo should remain")
        XCTAssertTrue(itemText("Charlie").exists, "Charlie should remain")
        XCTAssertFalse(itemText("Alpha").exists, "Alpha should be deleted")
    }

    func testSelectAllThenShiftDown() {
        createItem("Alpha")
        createItem("Bravo")
        createItem("Charlie")
        navigateToItem(at: 0)
        // Select all via Cmd+A
        app.typeKey("a", modifierFlags: .command)
        // Shift+Down should be a no-op (cursor already at last item).
        // All three should still be selected.
        app.typeKey(.downArrow, modifierFlags: .shift)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "All items should still be selected after Shift+Down at end"
        )
    }

    // MARK: - Cmd+Click Selection

    func testCmdClickDeselectsFromRange() {
        createItem("Alpha")
        createItem("Bravo")
        createItem("Charlie")
        navigateToItem(at: 0)
        // Extend selection to all three
        app.typeKey(.downArrow, modifierFlags: .shift)
        app.typeKey(.downArrow, modifierFlags: .shift)
        // Cmd+Click Bravo to deselect it
        cmdClickRow(withText: "Bravo")
        app.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(
            itemText("Bravo").waitForExistence(timeout: 2),
            "Bravo should remain (was deselected by Cmd+Click)"
        )
        XCTAssertFalse(itemText("Alpha").exists, "Alpha should be deleted")
        XCTAssertFalse(itemText("Charlie").exists, "Charlie should be deleted")
    }

    func testCmdClickAddsToSelection() {
        createItem("Alpha")
        createItem("Bravo")
        createItem("Charlie")
        navigateToItem(at: 0)
        // Cmd+Click Charlie to add it to selection
        cmdClickRow(withText: "Charlie")
        app.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(
            itemText("Bravo").waitForExistence(timeout: 2),
            "Bravo should remain (was not selected)"
        )
        XCTAssertFalse(itemText("Alpha").exists, "Alpha should be deleted")
        XCTAssertFalse(itemText("Charlie").exists, "Charlie should be deleted")
    }

    func testShiftUpAfterCmdClickDeselect() {
        createItem("Delta")
        createItem("Echo")
        createItem("Foxtrot")
        createItem("Golf")
        navigateToItem(at: 0)
        // Select Delta through Golf
        app.typeKey(.downArrow, modifierFlags: .shift)
        app.typeKey(.downArrow, modifierFlags: .shift)
        app.typeKey(.downArrow, modifierFlags: .shift)
        // Cmd+Click Echo to deselect: {Delta, Foxtrot, Golf}
        cmdClickRow(withText: "Echo")
        // Shift+Up contracts from cursor end: removes Golf → {Delta, Foxtrot}
        app.typeKey(.upArrow, modifierFlags: .shift)
        app.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(itemText("Echo").waitForExistence(timeout: 2), "Echo should remain")
        XCTAssertTrue(itemText("Golf").exists, "Golf should remain")
        XCTAssertFalse(itemText("Delta").exists, "Delta should be deleted")
        XCTAssertFalse(itemText("Foxtrot").exists, "Foxtrot should be deleted")
    }

    func testSelectAllAfterCmdClick() {
        createItem("Alpha")
        createItem("Bravo")
        createItem("Charlie")
        navigateToItem(at: 0)
        app.typeKey(.downArrow, modifierFlags: .shift)
        app.typeKey(.downArrow, modifierFlags: .shift)
        // Cmd+Click Bravo to create discontinuous selection {Alpha, Charlie}
        cmdClickRow(withText: "Bravo")
        // Cmd+A should select all, clearing any discontinuous state
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(
            emptyStateLabel.waitForExistence(timeout: 2),
            "All items should be deleted after Select All"
        )
    }
}
