@preconcurrency import XCTest

/// Focused checks for Today's Compact hero. The 100-point seed intentionally
/// disagrees with its older history value, so it also exercises trend parity.
@MainActor
final class TodayCompactUITests: SeededUITestBaseCase {
    private let workoutID = "exercise-compact-row"

    override var initialTabSelectionArgument: String? { "today" }

    override var additionalLaunchArguments: [String] {
        ["--ui-visual-condition-components-fixture",
         "--ui-test-theme", "desertWarm",
         "--ui-test-style", "light",
         "-morningBriefingDisabled", "YES",
         "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private var trendChart: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@",
            ["dashboard-hourly-condition-chart", "dashboard-weekly-condition-chart"]
        )).firstMatch
    }

    func testTodayInformationCardsAndHeaderActions() {
        var configuration = launchConfiguration
        configuration.additionalArguments.removeAll { $0 == "--ui-visual-condition-components-fixture" }
        configuration.additionalArguments += [
            "--ui-condition-score-fixture", "49",
            "--ui-visual-stress-fixture", "--ui-dashboard-hour", "8"
        ]
        launchApp(with: configuration)
        navigateToDashboard()
        XCTAssertTrue(element("dashboard-hero-condition").waitForExistence(timeout: 10))
        addScreenshotAttachment(named: "Today Repair T03 root and yesterday")
        for (cardID, actionID, name) in [
            ("dashboard-today-brief-card", "briefing-entry-card", "brief"),
            ("dashboard-recovery-sleep-card", "dashboard-recovery-sleep-details", "sleep"),
            ("dashboard-stress-score", "dashboard-stress-details", "stress")
        ] {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(actionID, maxSwipes: 16))
            let action = app.buttons[actionID].firstMatch
            let card = element(cardID)
            XCTAssertTrue(action.waitForExistence(timeout: 5))
            XCTAssertTrue(card.exists)
            XCTAssertLessThan(action.frame.minY - card.frame.minY, 55,
                              "\(name): details should share the header instead of reserving a footer")
            addScreenshotAttachment(named: "Today Repair \(name) information")
        }
        XCTAssertTrue(element("dashboard-stress-contributions").exists,
                      "Stress evidence must be present without expanding a disclosure")
    }

    func testInsightDismissTargetIncludesItsPadding() {
        var configuration = launchConfiguration
        configuration.additionalArguments.removeAll { $0 == "--ui-visual-condition-components-fixture" }
        configuration.additionalArguments += ["--ui-condition-score-fixture", "52"]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dismissalKey = "com.raftel.dailve.insightDismiss.\(dateFormatter.string(from: Date()))"
        // UserDefaults' argument domain supplies an empty array for this run,
        // even if a prior run dismissed the same card today.
        configuration.additionalArguments += ["-\(dismissalKey)", "()"]
        launchApp(with: configuration)
        navigateToDashboard()

        // Score 52 produces the fair-condition training insight. The seeded
        // 430-minute sleep and favorable weather provide a second coaching
        // insight, so one non-sleep card remains after focus selection.
        let dismissID = "dashboard-insight-dismiss-training-fair-normal"
        let dismiss = app.buttons[dismissID].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(dismissID, maxSwipes: 16),
                      "The seeded insight dismiss action should be reachable on Today")
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5), "The fair-condition seed must expose an insight dismiss action")
        XCTAssertGreaterThanOrEqual(dismiss.frame.width, 44)
        XCTAssertGreaterThanOrEqual(dismiss.frame.height, 44)
        let identifier = dismiss.identifier
        // Tap inside the target's clear padding rather than the small X glyph.
        dismiss.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.buttons[identifier]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        addScreenshotAttachment(named: "Today Insight dismissed through padded target")
    }

    private func launchWorkoutRow(language: String = "en", locale: String = "en_US", largeText: Bool = false) {
        var configuration = launchConfiguration
        configuration.additionalArguments = [
            "--ui-today-workout-row-fixture",
            "--ui-test-theme", "desertWarm",
            "--ui-test-style", "light",
            "-morningBriefingDisabled", "YES",
            "-AppleLanguages", "(\(language))", "-AppleLocale", locale
        ]
        if largeText {
            configuration.additionalArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        launchApp(with: configuration)
        navigateToDashboard()
    }

    private func assertBoundaryScore(_ expectedScore: Int) {
        var configuration = launchConfiguration
        configuration.additionalArguments.removeAll { $0 == "--ui-visual-condition-components-fixture" }
        configuration.additionalArguments += ["--ui-condition-score-fixture", String(expectedScore)]
        launchApp(with: configuration)
        navigateToDashboard()

        let hero = app.buttons["dashboard-hero-condition"].firstMatch
        let ring = element("dashboard-hero-ring")
        let chart = trendChart
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        XCTAssertEqual(ring.frame.width, 104, accuracy: 1)
        XCTAssertEqual(ring.frame.height, 104, accuracy: 1)
        XCTAssertTrue(ring.label.contains("Condition score \(expectedScore),"),
                      "The accessible ring must expose the exact seeded score")
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        XCTAssertTrue((chart.value as? String ?? "").contains("current \(expectedScore)."),
                      "The trend must report the displayed boundary score")
        addScreenshotAttachment(named: "Today Compact score \(expectedScore)")
    }

    func testZeroScoreKeepsCircularTrackAndReadableZero() {
        assertBoundaryScore(0)
    }

    func testOnePointRingKeepsFixedGeometry() {
        assertBoundaryScore(1)
    }

    func testMiddleScoreRingKeepsFixedGeometry() {
        assertBoundaryScore(52)
    }

    func testNinetyNinePointRingKeepsFixedGeometry() {
        assertBoundaryScore(99)
    }

    func testSeededHundredPointRingHasFixedCircularFrame() {
        navigateToDashboard()

        let hero = app.buttons["dashboard-hero-condition"].firstMatch
        let ring = element("dashboard-hero-ring")
        let trend = element("dashboard-hero-trend")
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        XCTAssertTrue(trend.waitForExistence(timeout: 5))
        XCTAssertEqual(ring.frame.width, 104, accuracy: 1, "Compact ring must retain its 104pt diameter")
        XCTAssertEqual(ring.frame.height, 104, accuracy: 1, "Compact ring must remain circular")
        XCTAssertTrue(hero.frame.contains(ring.frame), "The complete ring must fit inside its detail link")
        addScreenshotAttachment(named: "Today Compact 100 ring")
    }

    func testMaximumAccessibilityScoreMovesOutsideRingAndKeepsDetailRoute() {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToDashboard()

        let hero = app.buttons["dashboard-hero-condition"].firstMatch
        let score = element("dashboard-hero-score")
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(score.waitForExistence(timeout: 5), "Large type needs a readable external score")
        XCTAssertTrue(score.label.contains("100"), "The external score should expose the value in its accessibility label")
        XCTAssertTrue(score.label.contains("Condition score"), "The score should retain its spoken context")
        XCTAssertFalse(element("dashboard-hero-ring").exists, "The decorative ring should disappear at accessibility sizes")
        XCTAssertGreaterThan(score.frame.width, 0)
        XCTAssertTrue(hero.frame.contains(score.frame), "External score must stay within the detail link")
        addScreenshotAttachment(named: "Today Compact 100 accessibility score")

        let chart = trendChart
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(chart.identifier, maxSwipes: 8),
                      "Large-text trend and its legend should be reachable")
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        XCTAssertTrue((chart.value as? String ?? "").contains("current 100."),
                      "Large-text trend must keep the displayed current score")
        addScreenshotAttachment(named: "Today Compact 100 accessibility trend")

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("dashboard-hero-score", maxSwipes: 8, direction: .down))
        hero.tap()
        XCTAssertTrue(element("condition-score-detail-screen").waitForExistence(timeout: 8))
    }

    func testHundredPointHeroAndCurrentTrendAgreeBeforeDetailRoute() {
        navigateToDashboard()

        let hero = app.buttons["dashboard-hero-condition"].firstMatch
        let ring = element("dashboard-hero-ring")
        let chart = trendChart
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        XCTAssertTrue(ring.label.contains("100"), "The accessible hero score should reflect the seed")
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        XCTAssertTrue((chart.value as? String ?? "").contains("current 100."),
                      "The trend current value must match the displayed score, not stale history")
        hero.tap()
        XCTAssertTrue(element("condition-score-detail-screen").waitForExistence(timeout: 8))
    }

    func testOddPinnedMetricOccupiesFullFinalRow() {
        navigateToDashboard()

        // seedDefaultRecords explicitly saves HRV + RHR, independent of the
        // production store's three-category fallback. Add Sleep through the UI.
        let grid = element("dashboard-pinned-grid")
        XCTAssertTrue(grid.waitForExistence(timeout: 10))
        XCTAssertTrue(grid.buttons["dashboard-metric-hrv"].firstMatch.exists)
        XCTAssertTrue(grid.buttons["dashboard-metric-rhr"].firstMatch.exists)
        XCTAssertFalse(grid.buttons["dashboard-metric-sleep"].firstMatch.exists)
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("dashboard-pinned-edit", maxSwipes: 16))
        app.buttons["dashboard-pinned-edit"].firstMatch.tap()
        let sleepChoice = app.buttons["pinned-metrics-editor-row-sleep"].firstMatch
        XCTAssertTrue(sleepChoice.waitForExistence(timeout: 5))
        XCTAssertFalse(sleepChoice.isSelected, "The fixture must begin with Sleep unpinned")
        sleepChoice.tap()
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == true"), object: sleepChoice
        )
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed,
                       "Tapping the row center must select Sleep before saving")
        app.buttons["pinned-metrics-editor-done"].firstMatch.tap()

        let first = grid.buttons["dashboard-metric-hrv"].firstMatch
        let second = grid.buttons["dashboard-metric-rhr"].firstMatch
        let last = grid.buttons["dashboard-metric-sleep"].firstMatch
        for card in [first, second, last] {
            XCTAssertTrue(card.waitForExistence(timeout: 5), "All three selected pins must be inside the pinned grid")
        }
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("dashboard-metric-sleep", maxSwipes: 16))
        addScreenshotAttachment(named: "Today Compact odd pinned metrics")
        XCTAssertGreaterThanOrEqual(last.frame.minY, min(first.frame.maxY, second.frame.maxY) - 2)
        XCTAssertEqual(last.frame.minX, grid.frame.minX, accuracy: 2)
        XCTAssertEqual(last.frame.maxX, grid.frame.maxX, accuracy: 2,
                       "The last odd metric must use the whole row without a reserved half cell")
    }

    func testPinnedMetricsUseOneColumnAtStandardXXXLTextSize() {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"
        ]
        launchApp(with: configuration)
        navigateToDashboard()

        let grid = element("dashboard-pinned-grid")
        let first = app.buttons["dashboard-metric-hrv"].firstMatch
        let second = app.buttons["dashboard-metric-rhr"].firstMatch
        XCTAssertTrue(grid.waitForExistence(timeout: 10))
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("dashboard-metric-rhr", maxSwipes: 8),
                      "The second pinned card should be visible before comparing columns")
        addScreenshotAttachment(named: "Today Compact pinned metrics standard XXXL")
        XCTAssertGreaterThanOrEqual(second.frame.minY, first.frame.maxY - 2,
                                    "Standard XXXL should stack pinned metrics in one column")
        XCTAssertEqual(first.frame.minX, second.frame.minX, accuracy: 2)
        XCTAssertEqual(first.frame.maxX, second.frame.maxX, accuracy: 2)
    }

    func testCompactWorkoutRowPreservesDateValueAndDetailRoute() {
        launchWorkoutRow()
        let rowID = "dashboard-workout-\(workoutID)"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(rowID, maxSwipes: 20))

        let row = app.buttons[rowID].firstMatch
        let title = app.staticTexts["dashboard-workout-title-\(workoutID)"].firstMatch
        let date = app.staticTexts["dashboard-workout-date-\(workoutID)"].firstMatch
        let value = app.staticTexts["dashboard-workout-value-\(workoutID)"].firstMatch
        for text in [title, date, value] {
            XCTAssertTrue(text.waitForExistence(timeout: 5), "The compact workout row must preserve title, date, and value")
            XCTAssertFalse(text.label.isEmpty)
        }
        XCTAssertEqual(title.label, "Seated Cable Row")
        XCTAssertTrue(value.label.contains("34"))
        XCTAssertLessThanOrEqual(row.frame.height, 125,
                                 "A single workout value should not reserve an empty chart area")
        addScreenshotAttachment(named: "Today Compact workout row")

        row.tap()
        XCTAssertTrue(element("metric-detail-screen-exercise").waitForExistence(timeout: 8),
                      "The compact row must retain the exercise metric destination")
    }

    func testCompactWorkoutRowContainsTextAtMaximumAccessibilitySize() {
        for (language, locale, expectedTitle) in [
            ("en", "en_US", "Seated Cable Row"),
            ("ko", "ko_KR", "시티드 케이블 로우"),
            ("ja", "ja_JP", "シーテッドケーブルロー")
        ] {
            launchWorkoutRow(language: language, locale: locale, largeText: true)
            let rowID = "dashboard-workout-\(workoutID)"
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(rowID, maxSwipes: 20))

            let row = app.buttons[rowID].firstMatch
            let bounds = row.frame.insetBy(dx: -2, dy: -2)
            let title = app.staticTexts["dashboard-workout-title-\(workoutID)"].firstMatch
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            XCTAssertEqual(title.label, expectedTitle, "\(language): workout name should be localized")
            for identifier in ["dashboard-workout-title-", "dashboard-workout-date-", "dashboard-workout-value-"] {
                let text = app.staticTexts["\(identifier)\(workoutID)"].firstMatch
                XCTAssertTrue(text.waitForExistence(timeout: 5))
                XCTAssertFalse(text.label.isEmpty)
                XCTAssertTrue(bounds.contains(text.frame),
                              "\(language): \(identifier) must remain inside the workout row at large type")
            }
            addScreenshotAttachment(named: "Today Compact workout max text \(language)")
        }
    }

    func testWorkoutTypeMoreAndLessPreserveHiddenRows() {
        launchWorkoutRow()

        let first = app.buttons["dashboard-workout-exercise-compact-row"].firstMatch
        let second = app.buttons["dashboard-workout-exercise-compact-run"].firstMatch
        let third = app.buttons["dashboard-workout-exercise-compact-cycle"].firstMatch
        let disclosure = app.buttons["dashboard-workout-more"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertFalse(third.exists, "Only the two most recent exercise types should appear initially")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("dashboard-workout-more", maxSwipes: 20))
        XCTAssertTrue(disclosure.label.localizedCaseInsensitiveContains("Show more exercises"))
        XCTAssertEqual(disclosure.value as? String, "Collapsed")
        disclosure.tap()

        XCTAssertTrue(third.waitForExistence(timeout: 5), "More should reveal the older exercise type")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("dashboard-workout-more", maxSwipes: 6))
        XCTAssertTrue(disclosure.label.localizedCaseInsensitiveContains("Show fewer exercises"))
        XCTAssertEqual(disclosure.value as? String, "Expanded")
        addScreenshotAttachment(named: "Today Compact expanded workout types")
        disclosure.tap()
        XCTAssertFalse(third.exists, "Less should collapse the older exercise type")
        XCTAssertTrue(first.exists && second.exists, "The two recent exercise types should remain")
    }
}
