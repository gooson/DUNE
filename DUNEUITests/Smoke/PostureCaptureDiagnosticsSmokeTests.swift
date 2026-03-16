@preconcurrency import XCTest

@MainActor
final class PostureCaptureDiagnosticsSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-reset",
            "--posture-open-capture",
            "--posture-capture-diagnostics",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        try super.tearDownWithError()
    }

    func testLaunchesDirectlyIntoPostureCapture() throws {
        let navBar = app.navigationBars["Posture Assessment"].firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 8), "Posture capture should open from launch arguments")

        let diagnosticsPresetButton = app.descendants(matching: .any)["posture-diagnostics-preset"].firstMatch
        let cameraUnavailableFallback = app.buttons["Try Again"].firstMatch
        XCTAssertTrue(
            diagnosticsPresetButton.waitForExistence(timeout: 2)
                || cameraUnavailableFallback.waitForExistence(timeout: 2),
            "Diagnostics controls or the camera unavailable fallback should appear"
        )
    }
}
