@preconcurrency import XCTest

/// Seeded Today reading hierarchy and its notification consumer.
/// Each assertion targets a visible child: the expanded cards can exceed a viewport.
@MainActor
final class TodayReadingUITests: SeededUITestBaseCase {
    private enum Fixture {
        static let sleepValue = "dashboard-recovery-last-sleep-value"
        static let sleepChart = "dashboard-recovery-sleep-chart"
        static let sleepDetails = "dashboard-recovery-sleep-details"
        static let stressValue = "dashboard-stress-score-value"
        static let stressToggle = "dashboard-stress-analysis-toggle"
        static let stressContributions = "dashboard-stress-contributions"
        static let stressDetails = "dashboard-stress-details"
        static let digestCondition = "dashboard-digest-condition"
        static let digestSteps = "dashboard-digest-steps"
        static let digestToggle = "dashboard-digest-summary-toggle"
        static let digestSummary = "dashboard-digest-full-summary"
    }

    override var initialTabSelectionArgument: String? { "today" }

    override var additionalLaunchArguments: [String] {
        readingArguments(style: "light", largeText: false)
    }

    nonisolated private func readingArguments(style: String, largeText: Bool) -> [String] {
        var arguments = [
            "--ui-visual-stress-fixture", "--ui-dashboard-hour", "21",
            "--ui-test-style", style,
            "-morningBriefingDisabled", "YES",
            "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"
        ]
        if largeText {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        return arguments
    }

    private func launchReading(style: String, largeText: Bool = false) {
        var configuration = launchConfiguration
        configuration.additionalArguments = readingArguments(style: style, largeText: largeText)
        launchApp(with: configuration)
        navigateToDashboard()
        XCTAssertTrue(waitForReadingElement("dashboard-hero-condition"), "Seeded Today should load")
    }

    private func waitForReadingElement(_ identifier: String, timeout: TimeInterval = 10) -> Bool {
        app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: timeout)
    }

    private func reveal(_ identifier: String, maxSwipes: Int = 16) {
        if identifier == Fixture.stressContributions {
            // The VStack identifier propagates to the decorative trend image.
            // Readable evidence must target text, with small reversible scrolls.
            let text = app.staticTexts[identifier].firstMatch
            let scroll = app.scrollViews["dashboard-root-scroll"].firstMatch
            for _ in 0..<maxSwipes {
                if text.exists && text.isHittable { return }
                let isAbove = text.exists && text.frame.maxY < app.windows.firstMatch.frame.midY
                let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: isAbove ? 0.35 : 0.65))
                let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: isAbove ? 0.65 : 0.35))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            XCTFail("Readable stress evidence should be visible at this device width")
            return
        }
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(identifier, maxSwipes: maxSwipes),
            "\(identifier) should be reachable at this text size and device width"
        )
    }

    private func captureVariants(section: String, inspect: () -> Void) {
        for (style, largeText, suffix) in [
            ("light", false, "light"),
            ("dark", false, "dark"),
            ("light", true, "large")
        ] {
            launchReading(style: style, largeText: largeText)
            inspect()
            captureReading("TodayReading-\(section)-\(suffix)")
        }
    }

    private func captureReading(_ name: String) {
        if ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_HOST_ONLY"] == "1" {
            VisualAudit.capture(name)
        } else {
            addScreenshotAttachment(named: name)
        }
    }

    func testCurrentDeviceReadingCards() {
        navigateToDashboard()
        reveal(Fixture.sleepValue)
        captureReading("TodayReading-sleep-current")
        reveal(Fixture.sleepChart)
        captureReading("TodayReading-sleep-chart-current")
        reveal(Fixture.stressValue)
        captureReading("TodayReading-stress-current")
        reveal(Fixture.stressToggle)
        app.buttons[Fixture.stressToggle].firstMatch.tap()
        reveal(Fixture.stressContributions)
        captureReading("TodayReading-stress-analysis-current")
        reveal(Fixture.digestCondition)
        reveal(Fixture.digestSteps)
        captureReading("TodayReading-digest-current")
        reveal(Fixture.digestToggle)
        app.buttons[Fixture.digestToggle].firstMatch.tap()
        reveal(Fixture.digestSummary)
        captureReading("TodayReading-digest-summary-current")
    }

    func testRecoverySleepRendersAndCapturesVariants() {
        captureVariants(section: "sleep") {
            reveal(Fixture.sleepValue)
            XCTAssertTrue(waitForReadingElement(Fixture.sleepValue), "Last sleep must have a visible value")
            XCTAssertFalse(app.descendants(matching: .any)[Fixture.sleepValue].firstMatch.label.isEmpty)
        }
    }

    func testRecoverySleepChartAndDetailRoute() {
        navigateToDashboard()
        reveal(Fixture.sleepChart)
        XCTAssertTrue(waitForReadingElement(Fixture.sleepChart), "Seeded sleep history should render")
        captureReading("TodayReading-sleep-chart-light")
        reveal(Fixture.sleepDetails)
        app.buttons[Fixture.sleepDetails].firstMatch.tap()
        XCTAssertTrue(waitForReadingElement("metric-detail-screen-sleep"), "Sleep Details should open the metric detail")
    }

    func testStressAnalysisRendersAndCapturesVariants() {
        captureVariants(section: "stress") {
            reveal(Fixture.stressValue)
            XCTAssertTrue(waitForReadingElement(Fixture.stressValue), "The seeded stress score should render")
            XCTAssertTrue(app.descendants(matching: .any)[Fixture.stressValue].firstMatch.label.contains("42"),
                          "The opt-in stress fixture should show score 42")
            reveal(Fixture.stressToggle)
            app.buttons[Fixture.stressToggle].firstMatch.tap()
            reveal(Fixture.stressContributions)
            XCTAssertTrue(waitForReadingElement(Fixture.stressContributions), "Analysis should expose seeded factors")
            XCTAssertFalse(app.descendants(matching: .any)["cumulative-stress-detail-screen"].firstMatch.exists,
                           "Analysis disclosure should stay on Today")
        }
    }

    func testStressDetailIsSeparateFromAnalysisDisclosure() {
        navigateToDashboard()
        reveal(Fixture.stressToggle)
        app.buttons[Fixture.stressToggle].firstMatch.tap()
        XCTAssertTrue(waitForReadingElement(Fixture.stressContributions))
        reveal(Fixture.stressDetails)
        app.buttons[Fixture.stressDetails].firstMatch.tap()
        XCTAssertTrue(waitForReadingElement("cumulative-stress-detail-screen"),
                      "Explicit stress detail action should navigate")
    }

    func testDailyDigestRendersAndCapturesVariants() {
        captureVariants(section: "digest") {
            reveal(Fixture.digestCondition)
            XCTAssertTrue(waitForReadingElement(Fixture.digestCondition), "Condition should use DigestMetrics")
            reveal(Fixture.digestSteps)
            XCTAssertTrue(waitForReadingElement(Fixture.digestSteps), "Seeded step count should remain visible")
            reveal(Fixture.digestToggle)
            app.buttons[Fixture.digestToggle].firstMatch.tap()
            reveal(Fixture.digestSummary)
            XCTAssertTrue(waitForReadingElement(Fixture.digestSummary), "Disclosure should retain the original summary")
            XCTAssertFalse(app.descendants(matching: .any)[Fixture.digestSummary].firstMatch.label.isEmpty)
        }
    }

    func testNotificationDigestUsesSameExpandableCard() {
        var configuration = launchConfiguration
        configuration.scenario = .notificationRoutingSeeded
        configuration.additionalArguments = readingArguments(style: "light", largeText: false) + [
            "--ui-open-notification-title", "Daily Digest Route Fixture"
        ]
        launchApp(with: configuration)

        XCTAssertTrue(waitForReadingElement("notification-daily-digest-screen", timeout: 15))
        XCTAssertTrue(waitForReadingElement("dashboard-daily-digest", timeout: 15))
        XCTAssertTrue(waitForReadingElement(Fixture.digestCondition))
        XCTAssertTrue(waitForReadingElement("notification-daily-digest-sleep"))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "컨디션")).count, 1,
                       "The shared card should own the condition metric without a duplicate grid")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "걸음 수")).count, 1,
                       "The shared card should own the steps metric without a duplicate grid")
        reveal(Fixture.digestToggle)
        app.buttons[Fixture.digestToggle].firstMatch.tap()
        reveal(Fixture.digestSummary)
        XCTAssertTrue(waitForReadingElement(Fixture.digestSummary),
                      "Notification summary should preserve the original text")
        captureReading("TodayReading-notification-digest")
    }
}
