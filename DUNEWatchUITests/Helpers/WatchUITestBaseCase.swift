import XCTest

enum WatchAXID {
    static let homeRoot = "watch-home-root"
    static let homeCarousel = "watch-home-carousel"
    static let homeEmptyState = "watch-home-empty-state"
    static let homeAllExercisesCard = "watch-home-card-all-exercises"
    static let homeBrowseAllLink = "watch-home-browse-all-link"
    static let homeAllExercisesLabelFragments = ["All Exercises", "전체 운동", "すべてのエクササイズ"]
    static let quickStartScreen = "watch-quickstart-screen"
    static let quickStartList = "watch-quickstart-list"
    static let quickStartEmpty = "watch-quickstart-empty"
    static let quickStartCategoryPicker = "watch-quickstart-category-picker"
    static let quickStartSectionRecent = "watch-quickstart-section-recent"
    static let quickStartSectionPreferred = "watch-quickstart-section-preferred"
    static let quickStartSectionPopular = "watch-quickstart-section-popular"
    static let quickStartExerciseSquat = "watch-quickstart-exercise-ui-test-squat"
    static let quickStartExerciseCrunch = "watch-quickstart-exercise-crunch"
    static let quickStartExercisePlank = "watch-quickstart-exercise-plank"
    static let workoutPreviewScreen = "watch-workout-preview-screen"
    static let workoutPreviewStrengthList = "watch-workout-preview-strength-list"
    static let workoutPreviewStartButton = "watch-workout-start-button"
    static let workoutPreviewCardio = "watch-workout-preview-cardio"
    static let workoutPreviewCardioIndoorButton = "watch-workout-cardio-indoor-button"
    static let workoutPreviewCardioOutdoorButton = "watch-workout-cardio-outdoor-button"
    static let workoutPreviewLevelDecrease = "watch-workout-preview-level-decrease"
    static let workoutPreviewLevelValue = "watch-workout-preview-level-value"
    static let workoutPreviewLevelIncrease = "watch-workout-preview-level-increase"
    static let cardioLevelDecrease = "watch-cardio-level-decrease"
    static let cardioLevelValue = "watch-cardio-level-value"
    static let cardioLevelIncrease = "watch-cardio-level-increase"
    static let workoutPreviewStartLabels = ["Start", "시작", "開始"]
    static let sessionPagingRoot = "watch-session-paging-root"
    static let sessionMetricsScreen = "watch-session-metrics-screen"
    static let sessionMetricsCompleteSetButton = "watch-session-complete-set-button"
    static let sessionMetricsCompleteSetLabels = ["Complete Set", "세트 완료", "セット完了"]
    static let sessionMetricsLastSetFinish = "watch-session-last-set-finish"
    static let sessionMetricsLastSetFinishLabels = ["Finish Exercise", "운동 마치기", "エクササイズ終了"]
    static let sessionControlsScreen = "watch-session-controls-screen"
    static let sessionControlsEndButton = "watch-session-end-button"
    static let sessionControlsEndLabels = ["End", "종료", "終了"]
    static let sessionControlsPauseResumeButton = "watch-session-pause-resume-button"
    static let sessionControlsPauseResumeLabels = ["Pause", "일시정지", "一時停止", "Resume", "재개", "再開"]
    static let restTimerScreen = "watch-rest-timer-screen"
    static let restTimerEndButton = "watch-rest-timer-end"
    static let restTimerSkipButton = "watch-rest-timer-skip"
    static let restTimerSkipLabels = ["Skip", "건너뛰기", "スキップ"]
    static let setInputScreen = "watch-set-input-screen"
    static let setInputDoneButton = "watch-set-input-done"
    static let restTimerRPEBadge = "watch-rest-timer-rpe-badge"
    static let restTimerRPERate = "watch-rest-timer-rpe-rate"
    static let restTimerRPEConfirm = "watch-rest-timer-rpe-confirm"
    static let lastSetRPEAction = "watch-last-set-rpe-action"
    static let lastSetRPEActionLabels = ["Rate RPE", "RPE 기록", "RPEを記録", "Confirm RPE", "RPE 확정", "RPEを確定"]
    static let lastSetRPESheet = "watch-last-set-rpe-sheet"
    static let lastSetRPEDecrement = "watch-last-set-rpe-decrement"
    static let lastSetRPEIncrement = "watch-last-set-rpe-increment"
    static let lastSetRPEConfirm = "watch-last-set-rpe-confirm"
    static let sessionSummaryScreen = "watch-session-summary-screen"
    static let sessionSummaryEffortButton = "watch-summary-effort-button"
    static let sessionSummaryDoneButton = "watch-session-summary-done"
    static let sessionSummarySaveStatus = "watch-session-summary-save-status"
    static let sessionSummaryEffortSheet = "watch-session-summary-effort-sheet"
    static let sessionSummaryEffortDoneButton = "watch-session-summary-effort-done"
    static let sessionSummaryDoneLabels = ["Done", "완료", "完了", "Finishing...", "마무리 중...", "完了処理中..."]
}

class WatchUITestBaseCase: XCTestCase {
    let fixtureStrengthSetCount = 3

    enum LaunchScenario: String {
        case empty = "empty"
        case defaultSeeded = "default-seeded"
        case responsiveLayout = "responsive-layout"
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

    private func isApplicationRunning(_ application: XCUIApplication) -> Bool {
        switch application.state {
        case .runningForeground, .runningBackground, .runningBackgroundSuspended:
            return true
        default:
            return false
        }
    }

    @discardableResult
    private func terminateIfRunning(_ application: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
        guard isApplicationRunning(application) else { return true }
        application.terminate()
        return application.wait(for: .notRunning, timeout: timeout)
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
        _ = terminateIfRunning(app)
        app.launch()
    }

    func relaunchApp(withAdditionalArguments additionalArguments: [String]) {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: additionalArguments)
        launchApp(with: configuration)
    }

    override func tearDownWithError() throws {
        if let app {
            if let failureCount = testRun?.failureCount, failureCount > 0 {
                addScreenshotAttachment(named: defaultArtifactName(suffix: "failure"))
            }
            _ = terminateIfRunning(app, timeout: 2)
        }
        app = nil
        try super.tearDownWithError()
    }

    @discardableResult
    func elementExists(_ identifier: String, timeout: TimeInterval = 5) -> Bool {
        switch identifier {
        case WatchAXID.homeAllExercisesCard:
            return waitForButton(
                identifier: identifier,
                labelContains: WatchAXID.homeAllExercisesLabelFragments,
                timeout: timeout
            ) != nil
        case WatchAXID.workoutPreviewStartButton:
            return waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.workoutPreviewStartLabels,
                timeout: timeout
            ) != nil
        case WatchAXID.sessionMetricsCompleteSetButton:
            return waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.sessionMetricsCompleteSetLabels,
                timeout: timeout
            ) != nil
        case WatchAXID.sessionMetricsLastSetFinish:
            return waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.sessionMetricsLastSetFinishLabels,
                timeout: timeout
            ) != nil
        case WatchAXID.lastSetRPEAction:
            return waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.lastSetRPEActionLabels,
                timeout: timeout
            ) != nil
        case WatchAXID.sessionControlsEndButton:
            return waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.sessionControlsEndLabels,
                timeout: timeout
            ) != nil
        case WatchAXID.sessionControlsPauseResumeButton:
            return waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.sessionControlsPauseResumeLabels,
                timeout: timeout
            ) != nil
        case WatchAXID.restTimerSkipButton:
            return waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.restTimerSkipLabels,
                timeout: timeout
            ) != nil
        case WatchAXID.sessionSummaryDoneButton:
            return waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.sessionSummaryDoneLabels,
                timeout: timeout
            ) != nil
        default:
            break
        }

        return app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: timeout)
    }

    @discardableResult
    func tapElement(_ identifier: String, timeout: TimeInterval = 5) -> Bool {
        let element: XCUIElement
        switch identifier {
        case WatchAXID.homeAllExercisesCard:
            guard let button = waitForButton(
                identifier: identifier,
                labelContains: WatchAXID.homeAllExercisesLabelFragments,
                timeout: timeout
            ) else {
                return false
            }
            element = button
        case WatchAXID.workoutPreviewStartButton:
            guard let button = waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.workoutPreviewStartLabels,
                timeout: timeout
            ) else {
                return false
            }
            element = button
        case WatchAXID.sessionMetricsCompleteSetButton:
            guard let button = waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.sessionMetricsCompleteSetLabels,
                timeout: timeout
            ) else {
                return false
            }
            element = button
        case WatchAXID.sessionMetricsLastSetFinish:
            guard let button = waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.sessionMetricsLastSetFinishLabels,
                timeout: timeout
            ) else {
                return false
            }
            element = button
        case WatchAXID.lastSetRPEAction:
            guard let button = waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.lastSetRPEActionLabels,
                timeout: timeout
            ) else {
                return false
            }
            element = button
        case WatchAXID.sessionControlsEndButton:
            guard let button = waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.sessionControlsEndLabels,
                timeout: timeout
            ) else {
                return false
            }
            element = button
        case WatchAXID.sessionControlsPauseResumeButton:
            guard let button = waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.sessionControlsPauseResumeLabels,
                timeout: timeout
            ) else {
                return false
            }
            element = button
        case WatchAXID.restTimerSkipButton:
            guard let button = waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.restTimerSkipLabels,
                timeout: timeout
            ) else {
                return false
            }
            element = button
        case WatchAXID.sessionSummaryDoneButton:
            guard let button = waitForButton(
                identifier: identifier,
                exactLabels: WatchAXID.sessionSummaryDoneLabels,
                timeout: timeout
            ) else {
                return false
            }
            element = button
        default:
            element = app.descendants(matching: .any)[identifier].firstMatch
        }

        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    private func waitForButton(
        identifier: String,
        exactLabels: [String] = [],
        labelContains: [String] = [],
        timeout: TimeInterval = 5
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let identifiedButton = app.buttons[identifier].firstMatch
            if identifiedButton.exists {
                return identifiedButton
            }

            if !exactLabels.isEmpty {
                let labeledButton = app.buttons.matching(
                    NSPredicate(format: "label IN %@", exactLabels)
                ).firstMatch
                if labeledButton.exists {
                    return labeledButton
                }
            }

            for fragment in labelContains {
                let labeledButton = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", fragment)
                ).firstMatch
                if labeledButton.exists {
                    return labeledButton
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return nil
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
        let hasCarousel = elementExists(WatchAXID.homeCarousel, timeout: 1)
        let hasEmptyState = elementExists(WatchAXID.homeEmptyState, timeout: 1)
        let hasVisibleHomeCard = elementExists(WatchAXID.homeAllExercisesCard, timeout: 2)
        let hasBrowseLink = elementExists(WatchAXID.homeBrowseAllLink, timeout: 1)
        XCTAssertTrue(
            hasCarousel || hasEmptyState || hasVisibleHomeCard || hasBrowseLink,
            "Home should render a visible card or empty state control"
        )
    }

    func ensureQuickStartVisible(timeout: TimeInterval = 8) {
        XCTAssertTrue(elementExists(WatchAXID.quickStartScreen, timeout: timeout), "Quick Start root should render")
        let hasQuickstartList = elementExists(WatchAXID.quickStartList, timeout: 1)
        let hasQuickstartEmpty = elementExists(WatchAXID.quickStartEmpty, timeout: 1)
        let hasCategoryPicker = elementExists(WatchAXID.quickStartCategoryPicker, timeout: 1)
        let hasQuickstartExercise = elementExists(WatchAXID.quickStartExerciseSquat, timeout: 2)
        let hasSectionHeader = waitForAny(
            [
                WatchAXID.quickStartSectionRecent,
                WatchAXID.quickStartSectionPreferred,
                WatchAXID.quickStartSectionPopular
            ],
            timeout: 1
        ) != nil
        XCTAssertTrue(
            hasQuickstartList || hasQuickstartEmpty || hasCategoryPicker || hasQuickstartExercise || hasSectionHeader,
            "All Exercises screen should render"
        )
    }

    func openAllExercises() {
        ensureHomeVisible()

        let didTap = tapElement(WatchAXID.homeAllExercisesCard, timeout: 5)
            || tapElement(WatchAXID.homeBrowseAllLink, timeout: 3)

        XCTAssertTrue(didTap, "Should navigate to All Exercises from home")
        ensureQuickStartVisible()
    }

    func findQuickStartExercise(identifier: String, maxSwipes: Int = 6) -> XCUIElement? {
        // watchOS exposes the List as a CollectionView with the screen identifier.
        let scrollContainers = [
            app.tables[WatchAXID.quickStartList].firstMatch,
            app.collectionViews[WatchAXID.quickStartList].firstMatch,
            app.scrollViews[WatchAXID.quickStartList].firstMatch,
            app.tables[WatchAXID.quickStartScreen].firstMatch,
            app.collectionViews[WatchAXID.quickStartScreen].firstMatch,
            app.scrollViews[WatchAXID.quickStartScreen].firstMatch
        ]
        guard let scrollContainer = scrollContainers.first(where: { $0.exists }) else {
            attachQuickStartHierarchy()
            return nil
        }

        let exercise = scrollContainer.descendants(matching: .any)[identifier].firstMatch
        for swipeIndex in 0...maxSwipes {
            if exercise.exists && exercise.isHittable {
                return exercise
            }
            if swipeIndex < maxSwipes {
                // A full Watch swipe can jump over several 48pt rows on 40mm devices.
                let start = scrollContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                let end = scrollContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
                start.press(
                    forDuration: 0.1,
                    thenDragTo: end,
                    withVelocity: .slow,
                    thenHoldForDuration: 0.1
                )
            }
        }

        // If a list snaps past a middle row, scan back toward the top once.
        for _ in 0..<maxSwipes {
            let start = scrollContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
            let end = scrollContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            if exercise.exists && exercise.isHittable {
                return exercise
            }
        }

        attachQuickStartHierarchy()
        return nil
    }

    private func attachQuickStartHierarchy() {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = "All-Exercises-accessibility-hierarchy"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func startFixtureStrengthWorkout() {
        openAllExercises()

        guard let exercise = findQuickStartExercise(identifier: WatchAXID.quickStartExerciseSquat) else {
            XCTFail("Fixture Squat should be hittable in the All Exercises list")
            return
        }
        exercise.tap()

        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewScreen, timeout: 5), "Workout preview root should render")
        let hasStrengthList = elementExists(WatchAXID.workoutPreviewStrengthList, timeout: 1)
        let hasStartButton = elementExists(WatchAXID.workoutPreviewStartButton, timeout: 2)
        XCTAssertTrue(
            hasStrengthList || hasStartButton,
            "Workout preview should render strength content or Start button"
        )
        XCTAssertTrue(hasStartButton, "Workout preview should show Start button")
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton, timeout: 1), "Workout preview Start button should be tappable")

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
        if controlsPageVisible(timeout: 1) {
            return
        }

        let swipeActions: [() -> Void] = [
            { self.app.swipeUp() },
            { self.app.swipeUp() },
            { self.app.swipeDown() },
            { self.app.swipeDown() }
        ]

        for action in swipeActions {
            action()
            if controlsPageVisible(timeout: 2) {
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

    private func controlsPageVisible(timeout: TimeInterval) -> Bool {
        elementExists(WatchAXID.sessionControlsScreen, timeout: timeout)
            || elementExists(WatchAXID.sessionControlsEndButton, timeout: timeout)
            || elementExists(WatchAXID.sessionControlsPauseResumeButton, timeout: timeout)
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

    /// Checks the actual accessible button frame before the test performs any scrolling.
    func assertFirstViewportButtons(_ identifiers: [String], screenshot: String) {
        for identifier in identifiers {
            XCTAssertTrue(app.buttons[identifier].firstMatch.waitForExistence(timeout: 5), "Missing \(identifier)")
        }
        addScreenshotAttachment(named: defaultArtifactName(suffix: screenshot))

        let screen = app.frame
        XCTAssertGreaterThan(screen.width, 0)
        XCTAssertGreaterThan(screen.height, 0)
        for identifier in identifiers {
            // watchOS may expose a toolbar button and its nested control with the same identifier.
            let button = app.buttons[identifier].firstMatch
            let frame = button.frame
            XCTAssertTrue(button.isHittable, "\(identifier) must be tappable without scrolling")
            XCTAssertGreaterThan(frame.width, 0, "\(identifier) must have a real frame")
            XCTAssertGreaterThan(frame.height, 0, "\(identifier) must have a real frame")
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 1, "\(identifier) clips at left edge: \(frame), screen: \(screen)")
            XCTAssertGreaterThanOrEqual(frame.minY, screen.minY - 1, "\(identifier) clips at top edge: \(frame), screen: \(screen)")
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 1, "\(identifier) clips at right edge: \(frame), screen: \(screen)")
            XCTAssertLessThanOrEqual(frame.maxY, screen.maxY + 1, "\(identifier) clips at bottom edge: \(frame), screen: \(screen)")
        }
    }

    private func addSystemPermissionMonitor() {
        _ = addUIInterruptionMonitor(withDescription: "Watch System Alert") { alert in
            for label in ["Don't Allow", "허용 안 함", "許可しない", "Allow", "허용", "許可", "OK", "확인", "Continue", "계속", "続ける"] {
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
