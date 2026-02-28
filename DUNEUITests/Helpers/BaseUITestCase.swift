import XCTest

/// Shared base class for UI tests. Handles app launch, permission alerts,
/// and common setup so individual test files stay focused on scenarios.
@MainActor
class BaseUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        addSystemPermissionMonitor()
        app.launch()
    }
}
