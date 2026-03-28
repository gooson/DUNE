@preconcurrency import XCTest

/// Base class for all UI tests providing shared setup, interruption handling,
/// and convenience navigation helpers.
class UITestBaseCase: XCTestCase {
    enum LaunchScenario: String {
        case empty = "empty"
        case defaultSeeded = "default-seeded"
        case activityExerciseSeeded = "activity-exercise-seeded"
    }

    struct LaunchConfiguration {
        var resetState = true
        var shouldSeedMockData = false
        var scenario: LaunchScenario?
        var initialTabSelectionArgument: String?
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
            if let initialTabSelectionArgument {
                args.append(contentsOf: ["--uitest-initial-tab", initialTabSelectionArgument])
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
    var initialTabSelectionArgument: String? { nil }

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
            initialTabSelectionArgument: initialTabSelectionArgument,
            additionalArguments: additionalLaunchArguments,
            additionalEnvironment: additionalLaunchEnvironment
        )
    }

    private func isApplicationRunning(_ application: XCUIApplication) -> Bool {
        switch application.state {
        case .runningForeground, .runningBackground, .runningBackgroundSuspended:
            return true
        default:
            return false
        }
    }

    private static let appBundleID = "com.raftel.dailve"

    @discardableResult
    private func terminateIfRunning(_ application: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        guard isApplicationRunning(application) else { return true }
        application.terminate()
        if application.wait(for: .notRunning, timeout: timeout) {
            return true
        }
        // Graceful terminate failed — force-kill via simctl
        Self.forceTerminateAppProcess()
        return application.wait(for: .notRunning, timeout: 5)
    }

    /// Force-terminate the AUT via `xcrun simctl terminate`.
    /// Uses `posix_spawn` because Foundation `Process` is unavailable in the iOS Simulator SDK.
    private static func forceTerminateAppProcess() {
        var pid = pid_t()
        var args: [UnsafeMutablePointer<CChar>?] = [
            strdup("/usr/bin/xcrun"),
            strdup("simctl"),
            strdup("terminate"),
            strdup("booted"),
            strdup(appBundleID),
            nil
        ]
        defer { args.compactMap { $0 }.forEach { free($0) } }
        posix_spawn(&pid, "/usr/bin/xcrun", nil, nil, &args, nil)
        var status: Int32 = 0
        waitpid(pid, &status, 0)
    }

    override func tearDownWithError() throws {
        if let app {
            if let failureCount = testRun?.failureCount, failureCount > 0 {
                addScreenshotAttachment(named: defaultArtifactName(suffix: "failure"))
            }
            // Suppress terminate failures so a single stuck test doesn't cascade
            // into launch-timeout failures for all subsequent tests in this class.
            let savedContinueAfterFailure = continueAfterFailure
            continueAfterFailure = true
            _ = terminateIfRunning(app)
            continueAfterFailure = savedContinueAfterFailure
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

        // Ensure the previous AUT instance is fully terminated before launching.
        // If graceful terminate fails, force-kill via simctl to prevent cascade.
        if !terminateIfRunning(app) {
            Self.forceTerminateAppProcess()
            _ = app.wait(for: .notRunning, timeout: 5)
        }
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
        _ = app.waitAndTap(AXID.dashboardToolbarSettings)
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

    @discardableResult
    func tapSegment(in identifier: String, index: Int, timeout: TimeInterval = 5) -> XCUIElement {
        let segmentedControl = app.segmentedControls[identifier].firstMatch
        let fallbackControl = app.descendants(matching: .any)[identifier].firstMatch
        let control = segmentedControl.exists ? segmentedControl : fallbackControl

        XCTAssertTrue(control.waitForExistence(timeout: timeout), "Segmented control '\(identifier)' should exist")

        let segment = control.buttons.element(boundBy: index)
        XCTAssertTrue(segment.waitForExistence(timeout: timeout), "Segment \(index) should exist in '\(identifier)'")
        segment.tap()
        return segment
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

class ActivityExerciseSeededUITestBaseCase: SeededUITestBaseCase {
    override var uiScenario: LaunchScenario? { .activityExerciseSeeded }
    override var initialTabSelectionArgument: String? { "train" }
}
