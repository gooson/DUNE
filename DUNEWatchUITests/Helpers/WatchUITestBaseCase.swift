import XCTest

@MainActor
class WatchUITestBaseCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting-watch"]
        app.launch()
    }

    override func tearDownWithError() throws {
        if let app {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 2)
        }
        app = nil
        try super.tearDownWithError()
    }

    @discardableResult
    func elementExists(_ identifier: String, timeout: TimeInterval = 5) -> Bool {
        app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: timeout)
    }
}
