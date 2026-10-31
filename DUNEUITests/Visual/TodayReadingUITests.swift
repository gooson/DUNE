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

    private func reportViewport(_ scroll: XCUIElement) -> CGRect {
        let frame = scroll.frame.intersection(app.windows.firstMatch.frame)
        let navigation = app.navigationBars.firstMatch
        let top = max(frame.minY, navigation.exists ? navigation.frame.maxY + 8 : frame.minY)
        let tabBar = app.tabBars.firstMatch
        let bottom = tabBar.exists && tabBar.isHittable && tabBar.frame.minY > frame.midY
            ? min(frame.maxY, tabBar.frame.minY - 8) : frame.maxY
        return CGRect(x: frame.minX, y: top, width: frame.width, height: max(0, bottom - top))
    }

    private func revealReportElement(_ element: XCUIElement, in scroll: XCUIElement, whole: Bool) -> Bool {
        for _ in 0..<12 {
            let viewport = reportViewport(scroll)
            let frame = element.frame
            let horizontalFit = frame.minX >= viewport.minX - 2 && frame.maxX <= viewport.maxX + 2
            let verticalFit = whole ? viewport.contains(frame) : frame.intersection(viewport).height >= 24
            if horizontalFit && verticalFit && (!whole || element.isHittable) { return true }
            guard viewport.height > 100, scroll.frame.height > 0 else { return false }
            let movingUp = frame.midY >= viewport.midY
            let startY = movingUp ? viewport.maxY - 24 : viewport.minY + 24
            let endY = movingUp ? viewport.minY + 24 : viewport.maxY - 24
            let start = scroll.coordinate(withNormalizedOffset: CGVector(
                dx: 0.5, dy: (startY - scroll.frame.minY) / scroll.frame.height
            ))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(
                dx: 0.5, dy: (endY - scroll.frame.minY) / scroll.frame.height
            ))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        return false
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

    /// Position the digest title just below the measured navigation area before capturing.
    /// Hittability alone can leave the title above the viewport after scrolling to the toggle.
    private func alignDigestHeaderForCapture(discover: Bool = true) {
        // Label passes its identifier to the decorative icon as well as the text;
        // the icon is not a reliable hittable target at accessibility text sizes.
        // Discovery is needed only on first arrival. After expansion the metric
        // is above the viewport, so an upward-only reveal would scroll away.
        if discover { reveal(Fixture.digestCondition) }
        let header = readableText(Fixture.digestHeader)
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Digest title should expose a text anchor")
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.exists, "Today should provide a scrollable reading surface")
        let window = app.windows.firstMatch.frame
        let navigationBar = app.navigationBars.firstMatch
        let top = max(scroll.frame.minY, window.minY,
                      navigationBar.exists ? navigationBar.frame.maxY : window.minY)
        let bottom = min(scroll.frame.maxY, window.maxY)
        let targetY = top + 20

        for _ in 0..<10 {
            let offset = header.frame.minY - targetY
            if abs(offset) <= 24 { break }
            let distance = min(max(abs(offset), 28), max(40, (bottom - top) * 0.35))
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(
                CGVector(dx: 0, dy: offset > 0 ? -distance : distance)
            ), withVelocity: .slow, thenHoldForDuration: 0.2)
        }

        XCTAssertGreaterThanOrEqual(header.frame.minY, top - 4,
                                    "Digest title must not be hidden behind navigation")
        XCTAssertLessThanOrEqual(header.frame.minY, targetY + 32,
                                 "Digest title should anchor the top of the capture")
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

    func testDailyDigestCaptureTopLight() {
        launchReading(style: "light")
        captureDigestFraming(suffix: "ko-light")
    }

    func testDailyDigestCaptureTopAccessibilityText() {
        launchReading(style: "light", largeText: true)
        captureDigestFraming(suffix: "ko-axxxl")
    }

    private func captureDigestFraming(suffix: String) {
        alignDigestHeaderForCapture()
        XCTAssertTrue(waitForReadingElement(Fixture.digestDate))
        XCTAssertTrue(waitForReadingElement(Fixture.digestCondition))
        XCTAssertTrue(waitForReadingElement(Fixture.digestSteps))
        XCTAssertTrue(waitForReadingElement(Fixture.digestPreview))
        captureReading("T03-digest-collapsed-top-\(suffix)")

        reveal(Fixture.digestToggle)
        let toggle = app.buttons[Fixture.digestToggle].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(waitForReadingElement(Fixture.digestSummary))

        alignDigestHeaderForCapture(discover: false)
        captureReading("T03-digest-expanded-top-\(suffix)")
        reveal(Fixture.digestSummary)
        captureReading("T03-digest-expanded-body-\(suffix)")
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

    func testNotificationDigestReportPreservesDataAndDisclosure() {
        var configuration = launchConfiguration
        configuration.scenario = .notificationRoutingSeeded
        configuration.additionalArguments = readingArguments(style: "light", largeText: false) + [
            "--ui-open-notification-title", "Daily Digest Route Fixture"
        ]
        launchApp(with: configuration)

        XCTAssertTrue(waitForReadingElement("notification-daily-digest-screen", timeout: 15))
        XCTAssertTrue(waitForReadingElement("dashboard-daily-digest", timeout: 15))
        XCTAssertTrue(waitForReadingElement("notification-daily-digest-cover"))
        XCTAssertEqual(readableText(Fixture.digestHeader).label, "오늘의 리포트")
        XCTAssertTrue(waitForReadingElement(Fixture.digestCondition))
        XCTAssertTrue(waitForReadingElement("notification-daily-digest-activity"))
        XCTAssertTrue(waitForReadingElement("notification-daily-digest-workout"))
        XCTAssertTrue(waitForReadingElement("notification-daily-digest-sleep"))
        XCTAssertTrue(waitForReadingElement("notification-daily-digest-narrative"))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "컨디션")).count, 1,
                       "The report should show the recorded condition once")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "걸음 수")).count, 1,
                       "The report should show the recorded steps once")
        reveal(Fixture.digestPreview)
        let preview = readableText(Fixture.digestPreview)
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        let firstSentence = preview.label
        XCTAssertFalse(readableText(Fixture.digestSummary).exists)
        captureReading("T10-notification-report-collapsed")
        reveal(Fixture.digestToggle)
        app.buttons[Fixture.digestToggle].firstMatch.tap()
        reveal(Fixture.digestSummary)
        let summary = readableText(Fixture.digestSummary)
        XCTAssertTrue(summary.waitForExistence(timeout: 5),
                      "Notification summary should preserve the original text")
        XCTAssertTrue(summary.label.hasPrefix(firstSentence))
        XCTAssertGreaterThan(summary.label.count, firstSentence.count)
        XCTAssertFalse(readableText(Fixture.digestPreview).exists)
        captureReading("T10-notification-report-expanded")

        configuration.additionalArguments = readingArguments(style: "dark", largeText: true) + [
            "--ui-open-notification-title", "Daily Digest Route Fixture"
        ]
        launchApp(with: configuration)
        XCTAssertTrue(waitForReadingElement("notification-daily-digest-screen", timeout: 15))
        let reportScroll = app.scrollViews["notification-daily-digest-screen"].firstMatch
        XCTAssertTrue(reportScroll.waitForExistence(timeout: 5), "Report needs its own front scroll view")
        let title = readableText(Fixture.digestHeader)
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "오늘의 리포트")
        XCTAssertTrue(revealReportElement(title, in: reportScroll, whole: true),
                      "Report title must fit below navigation at maximum Dynamic Type")
        captureReading("T10-notification-report-dark-ax-title")
        for id in ["notification-daily-digest-workout", "notification-daily-digest-sleep"] {
            let section = app.descendants(matching: .any)[id].firstMatch
            XCTAssertTrue(section.waitForExistence(timeout: 5))
            XCTAssertTrue(revealReportElement(section, in: reportScroll, whole: false),
                          "\(id) must have a readable visible portion")
        }
        let largePreview = readableText(Fixture.digestPreview)
        XCTAssertTrue(largePreview.waitForExistence(timeout: 5))
        XCTAssertTrue(revealReportElement(largePreview, in: reportScroll, whole: false))
        let largeFirstSentence = largePreview.label
        let largeToggle = app.buttons[Fixture.digestToggle].firstMatch
        XCTAssertTrue(largeToggle.waitForExistence(timeout: 5))
        XCTAssertTrue(revealReportElement(largeToggle, in: reportScroll, whole: true),
                      "Summary control must fit and be tappable below navigation")
        XCTAssertGreaterThanOrEqual(largeToggle.frame.height, 44)
        captureReading("T10-notification-report-dark-ax-control")
        largeToggle.tap()
        let largeSummary = readableText(Fixture.digestSummary)
        XCTAssertTrue(largeSummary.waitForExistence(timeout: 5))
        XCTAssertTrue(revealReportElement(largeSummary, in: reportScroll, whole: false),
                      "Expanded summary needs an unclipped horizontal width and readable portion")
        XCTAssertTrue(largeSummary.label.hasPrefix(largeFirstSentence))
        XCTAssertGreaterThan(largeSummary.label.count, largeFirstSentence.count)
        // The expanded paragraph may span more than one viewport; its text must remain intact.
        captureReading("T10-notification-report-dark-ax")
    }
}
