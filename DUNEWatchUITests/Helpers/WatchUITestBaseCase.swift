import XCTest

enum WatchAXID {
    static let homeRoot = "watch-home-root"
    static let homeCarousel = "watch-home-carousel"
    static let homeEmptyState = "watch-home-empty-state"
    static let homeAllExercisesCard = "watch-home-card-all-exercises"
    static let homeBrowseAllLink = "watch-home-browse-all-link"
    static let quickStartScreen = "watch-quickstart-screen"
    static let quickStartList = "watch-quickstart-list"
    static let quickStartEmpty = "watch-quickstart-empty"
    static let quickStartSectionRecent = "watch-quickstart-section-recent"
    static let quickStartExerciseSquat = "watch-quickstart-exercise-ui-test-squat"
    static let workoutPreviewScreen = "watch-workout-preview-screen"
    static let workoutPreviewStrengthList = "watch-workout-preview-strength-list"
    static let workoutPreviewStartButton = "watch-workout-start-button"
    static let sessionPagingRoot = "watch-session-paging-root"
    static let sessionMetricsScreen = "watch-session-metrics-screen"
    static let sessionMetricsCompleteSetButton = "watch-session-complete-set-button"
    static let sessionMetricsLastSetFinish = "watch-session-last-set-finish"
    static let sessionControlsScreen = "watch-session-controls-screen"
    static let sessionControlsEndButton = "watch-session-end-button"
    static let sessionControlsPauseResumeButton = "watch-session-pause-resume-button"
    static let restTimerScreen = "watch-rest-timer-screen"
    static let restTimerSkipButton = "watch-rest-timer-skip"
    static let setInputScreen = "watch-set-input-screen"
    static let setInputDoneButton = "watch-set-input-done"
    static let sessionSummaryScreen = "watch-session-summary-screen"
    static let sessionSummaryEffortButton = "watch-summary-effort-button"
    static let sessionSummaryDoneButton = "watch-session-summary-done"
}

class WatchUITestBaseCase: XCTestCase {
    let fixtureStrengthSetCount = 3

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

    @discardableResult
    func tapElement(_ identifier: String, timeout: TimeInterval = 5) -> Bool {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    func waitForAny(_ identifiers: [String], timeout: TimeInterval = 5) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for identifier in identifiers {
                if app.descendants(matching: .any)[identifier].firstMatch.exists {
                    return identifier
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return nil
    }

    func ensureHomeVisible(timeout: TimeInterval = 10) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: timeout))
        XCTAssertTrue(elementExists(WatchAXID.homeRoot, timeout: timeout), "Home root should exist")
        let hasCarousel = elementExists(WatchAXID.homeCarousel, timeout: timeout)
        let hasEmptyState = elementExists(WatchAXID.homeEmptyState, timeout: timeout)
        XCTAssertTrue(hasCarousel || hasEmptyState, "Home should render either carousel or empty state")
    }

    func openAllExercises() {
        ensureHomeVisible()

        let allExercisesCard = app.descendants(matching: .any)[WatchAXID.homeAllExercisesCard].firstMatch
        let browseAllLink = app.descendants(matching: .any)[WatchAXID.homeBrowseAllLink].firstMatch

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

        XCTAssertTrue(elementExists(WatchAXID.quickStartScreen, timeout: 8), "Quick Start root should render")
        let hasQuickstartList = elementExists(WatchAXID.quickStartList, timeout: 8)
        let hasQuickstartEmpty = elementExists(WatchAXID.quickStartEmpty, timeout: 8)
        XCTAssertTrue(hasQuickstartList || hasQuickstartEmpty, "All Exercises screen should render")
    }

    func startFixtureStrengthWorkout() {
        openAllExercises()

        let exercise = app.descendants(matching: .any)[WatchAXID.quickStartExerciseSquat].firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 5), "Fixture exercise should be visible")
        exercise.tap()

        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewScreen, timeout: 5), "Workout preview root should render")
        XCTAssertTrue(
            elementExists(WatchAXID.workoutPreviewStrengthList, timeout: 5),
            "Workout preview strength list should render"
        )

        let startButton = app.descendants(matching: .any)[WatchAXID.workoutPreviewStartButton].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Workout preview should show Start button")
        startButton.tap()

        let startedIdentifier = waitForAny(
            [
                WatchAXID.sessionPagingRoot,
                WatchAXID.setInputScreen,
                WatchAXID.sessionMetricsScreen,
                WatchAXID.sessionMetricsCompleteSetButton
            ],
            timeout: 8
        )
        XCTAssertNotNil(startedIdentifier, "Workout session should start and show active session UI")
    }

    func dismissSetInputSheetIfNeeded(timeout: TimeInterval = 5) {
        guard app.descendants(matching: .any)[WatchAXID.setInputScreen].firstMatch.waitForExistence(timeout: timeout) else {
            return
        }
        XCTAssertTrue(tapElement(WatchAXID.setInputDoneButton), "Set input sheet should dismiss via Done")
        _ = waitForAny([WatchAXID.sessionMetricsScreen, WatchAXID.sessionMetricsCompleteSetButton], timeout: 5)
    }

    func openControlsPage() {
        dismissSetInputSheetIfNeeded()
        if elementExists(WatchAXID.sessionControlsScreen, timeout: 1) {
            return
        }

        let swipeActions: [() -> Void] = [
            { self.app.swipeDown() },
            { self.app.swipeRight() },
            { self.app.swipeLeft() },
            { self.app.swipeUp() }
        ]

        for action in swipeActions {
            action()
            if elementExists(WatchAXID.sessionControlsScreen, timeout: 2) {
                return
            }
        }

        XCTFail("Controls page should be reachable from the active session")
    }

    func completeOneSetAndReachRestTimer() {
        dismissSetInputSheetIfNeeded()
        XCTAssertTrue(tapElement(WatchAXID.sessionMetricsCompleteSetButton), "Complete Set button should exist")
        XCTAssertTrue(
            elementExists(WatchAXID.restTimerScreen, timeout: 5),
            "Rest timer should appear after completing a non-final set"
        )
    }

    func skipRestTimer() {
        XCTAssertTrue(
            tapElement(WatchAXID.restTimerSkipButton, timeout: 5),
            "Rest timer skip button should be available"
        )
    }

    func completeFixtureStrengthWorkoutToSummary() {
        startFixtureStrengthWorkout()

        for setIndex in 1...fixtureStrengthSetCount {
            dismissSetInputSheetIfNeeded()
            XCTAssertTrue(
                tapElement(WatchAXID.sessionMetricsCompleteSetButton, timeout: 5),
                "Complete Set button should exist for set \(setIndex)"
            )

            if setIndex < fixtureStrengthSetCount {
                XCTAssertTrue(
                    elementExists(WatchAXID.restTimerScreen, timeout: 5),
                    "Rest timer should appear after set \(setIndex)"
                )
                skipRestTimer()
            } else {
                XCTAssertTrue(
                    tapElement(WatchAXID.sessionMetricsLastSetFinish, timeout: 5),
                    "Finish Exercise action should exist after the last set"
                )
            }
        }

        XCTAssertTrue(
            elementExists(WatchAXID.sessionSummaryScreen, timeout: 8),
            "Workout summary should appear after finishing the fixture workout"
        )
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
