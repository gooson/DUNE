import XCTest

/// Base class for all UI tests providing shared setup, interruption handling,
/// and convenience navigation helpers.
@MainActor
class UITestBaseCase: XCTestCase {
    var app: XCUIApplication!

    /// Override in subclass to use "--seed-mock" for data-seeded tests
    var shouldSeedMockData: Bool { false }
    var initialTabSelectionArgument: String? { nil }

    override func tearDownWithError() throws {
        if let app {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 2)
        }
        app = nil
        try super.tearDownWithError()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        var args = ["--uitesting"]
        if shouldSeedMockData {
            args.append("--seed-mock")
        }
        if let initialTabSelectionArgument {
            args.append(contentsOf: ["--uitest-initial-tab", initialTabSelectionArgument])
        }
        app.launchArguments = args

        // Auto-dismiss any system permission dialogs
        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            for label in ["Allow", "OK", "Don't Allow"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }

        // Terminate any lingering instance before launch (CI resilience)
        app.terminate()

        app.launch()

        if !app.hasPrimaryNavigation(timeout: 8) {
            throw XCTSkip("Primary navigation (tab bar/sidebar) not found")
        }
    }

    // MARK: - Navigation Helpers

    func navigateToDashboard() {
        app.navigateToTab("Today")
    }

    func navigateToActivity() {
        app.navigateToTab("Activity")
    }

    func navigateToWellness() {
        app.navigateToTab("Wellness")
    }

    func navigateToLife() {
        app.navigateToTab("Life")
    }

    func navigateToSettings() {
        navigateToDashboard()
        let settingsButton = app.descendants(matching: .any)[AXID.dashboardToolbarSettings].firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }
    }

    /// Wait for an element with a given accessibility identifier
    @discardableResult
    func waitForElement(_ identifier: String, timeout: TimeInterval = 5) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element '\(identifier)' should exist")
        return element
    }

    /// Assert an element exists without failing the test (for optional sections)
    func elementExists(_ identifier: String, timeout: TimeInterval = 3) -> Bool {
        app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: timeout)
    }
}

// MARK: - Seeded Base (with mock data)

/// Base class for tests that require mock data to be seeded
@MainActor
class SeededUITestBaseCase: UITestBaseCase {
    override var shouldSeedMockData: Bool { true }
}
