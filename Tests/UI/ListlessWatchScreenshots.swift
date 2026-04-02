import XCTest

final class ListlessWatchScreenshots: XCTestCase {
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

    private func launchApp(_ additionalArgs: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"] + additionalArgs
        app.launch()
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

    func testScreenshot01_Items() throws {
        launchApp(["SCREENSHOT_SEED"])

        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))

        usleep(500_000)

        saveScreenshot(name: "01-items")
    }
}
