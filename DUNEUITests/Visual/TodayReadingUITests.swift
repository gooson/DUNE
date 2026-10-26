@preconcurrency import XCTest

/// Seeded Today reading hierarchy and its notification consumer.
/// Each assertion targets a visible child: the expanded cards can exceed a viewport.
@MainActor
final class TodayReadingUITests: SeededUITestBaseCase {
    private enum Fixture {
        static let sleepValue = "dashboard-recovery-last-sleep-value"
        static let sleepDate = "dashboard-recovery-last-sleep-date"
        static let sleepChart = "dashboard-recovery-sleep-chart"
        static let sleepDetails = "dashboard-recovery-sleep-details"
        static let stressValue = "dashboard-stress-score-value"
        static let stressContributions = "dashboard-stress-contributions"
        static let stressHRV = "dashboard-stress-contribution-hrvVariability"
        static let stressSleep = "dashboard-stress-contribution-sleepConsistency"
        static let stressActivity = "dashboard-stress-contribution-activityLoad"
        static let stressDetails = "dashboard-stress-details"
        static let digestCondition = "dashboard-digest-condition"
        static let digestSteps = "dashboard-digest-steps"
        static let digestHeader = "dashboard-digest-header"
        static let digestDate = "dashboard-digest-date"
        static let digestPreview = "dashboard-digest-preview"
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

    /// A container or decorative shape can inherit the identifier from SwiftUI.
    /// Read the actual text node when asserting content.
    private func readableText(_ identifier: String) -> XCUIElement {
        app.staticTexts[identifier].firstMatch
    }

    private func reveal(_ identifier: String, maxSwipes: Int = 16) {
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
        reveal(Fixture.stressHRV)
        captureReading("TodayReading-stress-analysis-current")
    }

    func testRecoverySleepRendersAndCapturesVariants() {
        captureVariants(section: "sleep") {
            reveal(Fixture.sleepValue)
            let value = readableText(Fixture.sleepValue)
            let date = readableText(Fixture.sleepDate)
            XCTAssertTrue(value.waitForExistence(timeout: 5), "Last sleep must have readable text")
            XCTAssertTrue(date.waitForExistence(timeout: 5), "Last sleep must retain its recorded date")
            XCTAssertFalse(value.label.isEmpty)
            XCTAssertFalse(date.label.isEmpty)
            XCTAssertGreaterThanOrEqual(date.frame.minY, value.frame.maxY - 2,
                                        "The sleep date should follow its value")
        }
    }

    func testRecoverySleepChartAndDetailRoute() {
        navigateToDashboard()
        reveal(Fixture.sleepChart)
        XCTAssertTrue(waitForReadingElement(Fixture.sleepChart), "Seeded sleep history should render")
        captureReading("TodayReading-sleep-chart-light")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(Fixture.sleepDetails, maxSwipes: 16, direction: .down),
                      "The sleep detail action should be reachable in the card header")
        app.buttons[Fixture.sleepDetails].firstMatch.tap()
        XCTAssertTrue(waitForReadingElement("metric-detail-screen-sleep"), "Sleep Details should open the metric detail")
    }

    func testStressAnalysisRendersAndCapturesVariants() {
        captureVariants(section: "stress") {
            reveal(Fixture.stressValue)
            let value = readableText(Fixture.stressValue)
            XCTAssertTrue(value.waitForExistence(timeout: 5), "The seeded stress score should render")
            XCTAssertTrue(value.label.contains("42"),
                          "The opt-in stress fixture should show score 42")
            reveal(Fixture.stressHRV)
            XCTAssertTrue(waitForReadingElement(Fixture.stressContributions), "Measured evidence should appear without interaction")
            for (factor, expectedDetail) in [
                (Fixture.stressHRV, "Recent HRV pattern"),
                (Fixture.stressSleep, "Recent sleep consistency"),
                (Fixture.stressActivity, "Recent training load")
            ] {
                let evidence = readableText(factor)
                XCTAssertTrue(evidence.waitForExistence(timeout: 5), "Each seeded factor should be readable on Today")
                XCTAssertEqual(evidence.label, expectedDetail)
            }
            XCTAssertFalse(app.descendants(matching: .any)["cumulative-stress-detail-screen"].firstMatch.exists,
                           "Inline evidence should stay on Today")
        }
    }

    func testStressDetailOpensFromHeader() {
        navigateToDashboard()
        reveal(Fixture.stressDetails)
        app.buttons[Fixture.stressDetails].firstMatch.tap()
        XCTAssertTrue(waitForReadingElement("cumulative-stress-detail-screen"),
                      "Explicit stress detail action should navigate")
    }

    func testDailyDigestCollapsedExpandedKorean() {
        launchReading(style: "light")
        assertDigestReading(captureSuffix: "ko-light")
    }

    func testDailyDigestAccessibilityText() {
        launchReading(style: "light", largeText: true)
        assertDigestReading(captureSuffix: "ko-axxxl")
    }

    private func assertDigestReading(captureSuffix: String) {
        reveal(Fixture.digestCondition)
        XCTAssertTrue(waitForReadingElement(Fixture.digestCondition), "Condition should use DigestMetrics")
        reveal(Fixture.digestSteps)
        XCTAssertTrue(waitForReadingElement(Fixture.digestSteps), "Seeded step count should remain visible")
        XCTAssertTrue(waitForReadingElement(Fixture.digestHeader), "Digest title should be readable")
        XCTAssertTrue(waitForReadingElement(Fixture.digestDate), "Digest date should be readable")

        reveal(Fixture.digestPreview)
        let preview = readableText(Fixture.digestPreview)
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "The first sentence should appear by default")
        let firstSentence = preview.label
        XCTAssertFalse(firstSentence.isEmpty)
        XCTAssertFalse(readableText(Fixture.digestSummary).exists, "The complete summary starts hidden")

        reveal(Fixture.digestToggle)
        let toggle = app.buttons[Fixture.digestToggle].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.label, "요약 더 보기")
        let collapsedValue = toggle.value as? String
        XCTAssertNotNil(collapsedValue, "VoiceOver should announce the collapsed state")
        XCTAssertFalse(collapsedValue?.isEmpty ?? true)
        XCTAssertGreaterThanOrEqual(toggle.frame.height, 44, "The entire disclosure row should be tappable")
        captureReading("T03-digest-collapsed-\(captureSuffix)")

        // Tap near the glyph on the trailing side of the button, still within its hit target.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        reveal(Fixture.digestSummary)
        let summary = readableText(Fixture.digestSummary)
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Expansion should reveal the original summary")
        let originalSummary = summary.label
        XCTAssertTrue(originalSummary.hasPrefix(firstSentence), "Preview should preserve the summary's first sentence")
        XCTAssertGreaterThan(originalSummary.count, firstSentence.count, "Seeded digest should have more than one sentence")
        XCTAssertFalse(readableText(Fixture.digestPreview).exists, "Expanded text replaces the preview")
        XCTAssertEqual(toggle.label, "요약 접기")
        let expandedValue = toggle.value as? String
        XCTAssertNotNil(expandedValue, "VoiceOver should announce the expanded state")
        XCTAssertNotEqual(expandedValue, collapsedValue)
        captureReading("T03-digest-expanded-\(captureSuffix)")

        reveal(Fixture.digestToggle)
        toggle.tap()
        reveal(Fixture.digestPreview)
        XCTAssertEqual(readableText(Fixture.digestPreview).label, firstSentence)
        XCTAssertFalse(readableText(Fixture.digestSummary).exists)
        XCTAssertEqual(toggle.value as? String, collapsedValue)
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
        reveal(Fixture.digestPreview)
        let preview = readableText(Fixture.digestPreview)
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        let firstSentence = preview.label
        XCTAssertFalse(readableText(Fixture.digestSummary).exists)
        captureReading("T03-notification-digest-collapsed")
        reveal(Fixture.digestToggle)
        app.buttons[Fixture.digestToggle].firstMatch.tap()
        reveal(Fixture.digestSummary)
        let summary = readableText(Fixture.digestSummary)
        XCTAssertTrue(summary.waitForExistence(timeout: 5),
                      "Notification summary should preserve the original text")
        XCTAssertTrue(summary.label.hasPrefix(firstSentence))
        XCTAssertGreaterThan(summary.label.count, firstSentence.count)
        XCTAssertFalse(readableText(Fixture.digestPreview).exists)
        captureReading("T03-notification-digest-expanded")
    }
}
