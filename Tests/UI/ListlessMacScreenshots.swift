import CoreGraphics
import XCTest

@MainActor
final class ListlessMacScreenshots: XCTestCase {
    var app: XCUIApplication!

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Helpers

    private func launchApp(_ additionalArgs: [String] = []) {
        app = XCUIApplication()
        let appearance = additionalArgs.contains("SCREENSHOT_DARK") ? "SCREENSHOT_DARK" : "SCREENSHOT_LIGHT"
        app.launchArguments = ["UI_TESTING", appearance] + additionalArgs.filter { $0 != "SCREENSHOT_DARK" }
        app.launch()
    }

    var draftTextField: XCUIElement {
        app.textFields["draft-row-append"]
    }

    func itemText(_ title: String) -> XCUIElement {
        app.textFields.matching(
            NSPredicate(format: "identifier BEGINSWITH 'item-text-' AND value == %@", title)
        ).firstMatch
    }

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

    func itemCheckbox(at index: Int) -> XCUIElement {
        app.buttons.matching(identifier: "item-checkbox").element(boundBy: index)
    }

    func navigateToItem(at index: Int) {
        app.typeKey(.escape, modifierFlags: [])
        for _ in 0...index {
            app.typeKey(.downArrow, modifierFlags: [])
        }
    }

    func cmdClickRow(withText title: String) {
        let textField = itemText(title)
        XCTAssertTrue(textField.waitForExistence(timeout: 2))
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

    func saveScreenshot(name: String) {
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] ?? []

        guard let windowID = windowList.first(where: {
            ($0[kCGWindowOwnerName as String] as? String) == "Listless"
                && ($0[kCGWindowLayer as String] as? Int) == 0
        })?[kCGWindowNumber as String] as? Int else {
            XCTFail("Could not find Listless window")
            return
        }

        let tmpFile = NSTemporaryDirectory() + "\(name).png"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-l\(windowID)", tmpFile]
        try? process.run()
        process.waitUntilExit()

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: tmpFile)) else {
            XCTFail("screencapture failed to write \(tmpFile)")
            return
        }

        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        try? FileManager.default.removeItem(atPath: tmpFile)
    }

    // MARK: - Screenshots

    /// Four items with draft row focused: three active, one empty draft row,
    /// one completed at the bottom.
    func testScreenshot01_ItemsWithEditing() throws {
        launchApp()

        createItem("Add items on your iPhone")
        createItem("Edit items on your iPad")
        createItem("Reorder items on your Mac")
        createItem("Complete items on your Watch")

        app.typeKey(.escape, modifierFlags: [])
        usleep(500_000)

        // Complete the last item
        let checkbox = itemCheckbox(at: 3)
        XCTAssertTrue(checkbox.waitForExistence(timeout: 2))
        checkbox.click()
        usleep(500_000)

        // Create an empty draft row
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(draftTextField.waitForExistence(timeout: 2))
        usleep(300_000)

        saveScreenshot(name: "01-items")
    }

    /// Single item in dark mode.
    func testScreenshot02_DarkMode() throws {
        launchApp(["SCREENSHOT_DARK"])

        createItem("Ask Alfred about utility belt")

        usleep(500_000)

        saveScreenshot(name: "02-click-to-create")
    }

    /// Multiple items with discontinuous selection via Cmd+Click.
    func testScreenshot03_MultipleSelection() throws {
        launchApp()

        createItem("Write shell script")
        createItem("Rewrite shell script")
        createItem("Question life choices")
        createItem("Cry tragically")
        createItem("Achieve catharsis")

        app.typeKey(.escape, modifierFlags: [])
        usleep(500_000)

        // Navigate to first item then select it
        navigateToItem(at: 0)
        usleep(200_000)

        // Cmd+Click to add non-adjacent items to selection
        cmdClickRow(withText: "Question life choices")
        cmdClickRow(withText: "Achieve catharsis")
        usleep(300_000)

        saveScreenshot(name: "03-selection")
    }
}
