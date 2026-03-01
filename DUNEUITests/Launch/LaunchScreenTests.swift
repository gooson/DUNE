import XCTest

final class DailveUITestsLaunchTests: XCTestCase {
    private var app: XCUIApplication!

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Terminate any lingering instance before launch (CI resilience)
        app.terminate()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        // Allow the app process to fully exit (CI resilience)
        Thread.sleep(forTimeInterval: 1)
        app = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testLaunch() throws {
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
