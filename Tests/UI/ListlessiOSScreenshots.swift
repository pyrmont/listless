import XCTest

final class ListlessiOSScreenshots: XCTestCase {
    var app: XCUIApplication!

    static let screenshotDir = "/tmp/listless-screenshots"

    override class func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(
            atPath: screenshotDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Helpers

    private func launchApp(_ additionalArgs: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"] + additionalArgs
        app.launch()
    }

    var draftTextField: XCUIElement {
        app.textViews.matching(identifier: "draft-row-append").firstMatch
    }

    var itemListScrollView: XCUIElement {
        app.scrollViews["item-list-scrollview"]
    }

    func createItem(_ title: String) {
        let textView = draftTextField
        if !textView.exists {
            itemListScrollView.tap()
            _ = textView.waitForExistence(timeout: 2)
        }
        textView.tap()
        textView.typeText(title + "\n")
    }

    func itemCheckbox(at index: Int) -> XCUIElement {
        app.buttons.matching(identifier: "item-checkbox").element(boundBy: index)
    }

    func exitEditingMode() {
        let draft = draftTextField
        if draft.exists {
            draft.typeText("\n")
        }
    }

    func saveScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let data = screenshot.pngRepresentation
        let path = "\(Self.screenshotDir)/\(name).png"
        try? data.write(to: URL(fileURLWithPath: path))
    }

    // MARK: - Screenshots

    /// Five items with keyboard up: three active, one empty draft row focused,
    /// one completed at the bottom.
    func testScreenshot01_ItemsWithKeyboard() throws {
        launchApp()

        createItem("Add items on your iPhone")
        createItem("Edit items on your iPad")
        createItem("Reorder items on your Mac")
        createItem("Complete items on your Watch")
        exitEditingMode()

        usleep(500_000)

        // Complete the last item
        let checkbox = itemCheckbox(at: 3)
        XCTAssertTrue(checkbox.waitForExistence(timeout: 2))
        checkbox.tap()

        usleep(500_000)

        // Tap below items to create an empty focused draft row
        let bottomArea = itemListScrollView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)
        )
        bottomArea.tap()
        XCTAssertTrue(draftTextField.waitForExistence(timeout: 2))
        usleep(300_000)

        saveScreenshot(name: "01-items")
    }

    /// Empty list showing the "Pull down to create" hint.
    func testScreenshot02_EmptyState() throws {
        launchApp()

        usleep(500_000)

        saveScreenshot(name: "02-empty-state")
    }

    /// Two items with the first row swiped right past the complete threshold.
    /// Collaroy colour theme.
    func testScreenshot03_SwipeComplete() throws {
        launchApp(["THEME_COLLAROY", "SCREENSHOT_SWIPE"])

        createItem("Slide left to complete")
        createItem("Slide right to delete")
        exitEditingMode()

        usleep(500_000)

        saveScreenshot(name: "03-swipe")
    }

    /// Settings sheet.
    func testScreenshot04_Settings() throws {
        launchApp(["SCREENSHOT_SHOW_SETTINGS"])

        usleep(500_000)

        saveScreenshot(name: "04-settings")
    }
}
