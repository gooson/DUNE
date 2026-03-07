import XCTest

class WatchUITestBaseCase: XCTestCase {
    enum LaunchScenario: String {
        case empty = "empty"
        case defaultSeeded = "default-seeded"
    }

    struct LaunchConfiguration {
        var resetState = true
        var shouldSeedMockData = true
        var scenario: LaunchScenario?
        var additionalArguments: [String] = []

        var launchArguments: [String] {
            var args = ["--uitesting-watch"]
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

    var shouldResetState: Bool { true }

    var shouldSeedMockData: Bool { true }

    var uiScenario: LaunchScenario? {
        shouldSeedMockData ? .defaultSeeded : .empty
    }

    var additionalLaunchArguments: [String] { [] }

    var launchConfiguration: LaunchConfiguration {
        LaunchConfiguration(
            resetState: shouldResetState,
            shouldSeedMockData: shouldSeedMockData,
            scenario: uiScenario,
            additionalArguments: additionalLaunchArguments
        )
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchApp()
    }

    func launchApp(with configuration: LaunchConfiguration? = nil) {
        app = XCUIApplication()
        let resolvedConfiguration = configuration ?? launchConfiguration
        app.launchArguments = resolvedConfiguration.launchArguments
        addSystemPermissionMonitor()
        app.terminate()
        app.launch()
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

    @discardableResult
    func elementExists(_ identifier: String, timeout: TimeInterval = 5) -> Bool {
        app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: timeout)
    }

    func ensureHomeVisible(timeout: TimeInterval = 10) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: timeout))
        let hasCarousel = elementExists("watch-home-carousel", timeout: timeout)
        let hasEmptyState = elementExists("watch-home-empty-state", timeout: timeout)
        XCTAssertTrue(hasCarousel || hasEmptyState, "Home should render either carousel or empty state")
    }

    func openAllExercises() {
        ensureHomeVisible()

        let allExercisesCard = app.descendants(matching: .any)["watch-home-card-all-exercises"].firstMatch
        let browseAllLink = app.descendants(matching: .any)["watch-home-browse-all-link"].firstMatch

        var didTap = false
        if allExercisesCard.waitForExistence(timeout: 2) {
            allExercisesCard.tap()
            didTap = true
        } else {
            for _ in 0..<8 where !didTap {
                app.swipeUp()
                if allExercisesCard.waitForExistence(timeout: 1) {
                    allExercisesCard.tap()
                    didTap = true
                }
            }
        }

        if !didTap, browseAllLink.waitForExistence(timeout: 2) {
            browseAllLink.tap()
            didTap = true
        }

        XCTAssertTrue(didTap, "Should navigate to All Exercises from home")

        let hasQuickstartList = elementExists("watch-quickstart-list", timeout: 8)
        let hasQuickstartEmpty = elementExists("watch-quickstart-empty", timeout: 8)
        XCTAssertTrue(hasQuickstartList || hasQuickstartEmpty, "All Exercises screen should render")
    }

    func startFixtureStrengthWorkout() {
        openAllExercises()

        let exercise = app.descendants(matching: .any)["watch-quickstart-exercise-ui-test-squat"].firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 5), "Fixture exercise should be visible")
        exercise.tap()

        let startButton = app.descendants(matching: .any)["watch-workout-start-button"].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Workout preview should show Start button")
        startButton.tap()

        let started = app.descendants(matching: .any)["watch-session-complete-set-button"].firstMatch.waitForExistence(timeout: 8)
        XCTAssertTrue(started, "Workout session should start and show active session UI")
    }

    func defaultArtifactName(suffix: String) -> String {
        let rawTestName = name.split(separator: " ").last.map(String.init) ?? "WatchUITest"
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

    private func addSystemPermissionMonitor() {
        _ = addUIInterruptionMonitor(withDescription: "Watch System Alert") { alert in
            for label in ["Allow", "OK", "Continue"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }
}
