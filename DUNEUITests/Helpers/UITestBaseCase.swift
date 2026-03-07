import XCTest

/// Base class for all UI tests providing shared setup, interruption handling,
/// and convenience navigation helpers.
class UITestBaseCase: XCTestCase {
    enum LaunchScenario: String {
        case empty = "empty"
        case defaultSeeded = "default-seeded"
    }

    struct LaunchConfiguration {
        var resetState = true
        var shouldSeedMockData = false
        var scenario: LaunchScenario?
        var additionalArguments: [String] = []
        var additionalEnvironment: [String: String] = [:]

        var launchArguments: [String] {
            var args = ["--uitesting"]
            if resetState {
                args.append("--ui-reset")
            }
            if shouldSeedMockData {
                args.append("--seed-mock")
            }
            if let scenario {
                args.append(contentsOf: ["--ui-scenario", scenario.rawValue])
            }
            args.append(contentsOf: additionalArguments)
            return args
        }
    }

    var app: XCUIApplication!

    /// Override in subclass to opt into an isolated in-memory launch.
    var shouldResetState: Bool { true }

    /// Override in subclass to use "--seed-mock" for data-seeded tests.
    var shouldSeedMockData: Bool { false }

    /// Override in subclass for scenario-specific seeded states.
    var uiScenario: LaunchScenario? {
        shouldSeedMockData ? .defaultSeeded : .empty
    }

    /// Override in subclass for extra launch arguments.
    var additionalLaunchArguments: [String] { [] }

    /// Override in subclass for extra launch environment.
    var additionalLaunchEnvironment: [String: String] { [:] }

    var launchConfiguration: LaunchConfiguration {
        LaunchConfiguration(
            resetState: shouldResetState,
            shouldSeedMockData: shouldSeedMockData,
            scenario: uiScenario,
            additionalArguments: additionalLaunchArguments,
            additionalEnvironment: additionalLaunchEnvironment
        )
    }

    override func tearDownWithError() throws {
        if let app {
            if let failureCount = testRun?.failureCount, failureCount > 0 {
                addScreenshotAttachment(named: defaultArtifactName(suffix: "failure"))
            }
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 2)
        }
        app = nil
        try super.tearDownWithError()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        launchApp()

        if !app.hasPrimaryNavigation(timeout: 8) {
            throw XCTSkip("Primary navigation (tab bar/sidebar) not found")
        }
    }

    func launchApp(with configuration: LaunchConfiguration? = nil) {
        app = XCUIApplication()
        let resolvedConfiguration = configuration ?? launchConfiguration
        app.launchArguments = resolvedConfiguration.launchArguments
        app.launchEnvironment.merge(resolvedConfiguration.additionalEnvironment) { _, new in new }

        addSystemPermissionMonitor()

        // Terminate any lingering instance before launch (CI resilience)
        app.terminate()
        app.launch()
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

    func defaultArtifactName(suffix: String) -> String {
        let rawTestName = name.split(separator: " ").last.map(String.init) ?? "UITest"
        let sanitizedTestName = rawTestName.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        return "\(type(of: self))-\(sanitizedTestName)-\(suffix)"
    }

    func addScreenshotAttachment(named name: String, lifetime: XCTAttachment.Lifetime = .keepAlways) {
        guard let app else { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = lifetime
        add(attachment)
    }
}

// MARK: - Seeded Base (with mock data)

/// Base class for tests that require mock data to be seeded
class SeededUITestBaseCase: UITestBaseCase {
    override var shouldSeedMockData: Bool { true }
}
