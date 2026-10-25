@preconcurrency import XCTest

/// Focused recorded-history and destination checks for the Activity and Life heroes.
/// Capture selectors are intentionally separate so the host can run one device/style
/// at a time and preserve native screenshots for A01/L01.
@MainActor
final class HeroRhythmUITests: SeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-hero-rhythm-fixtures", "-morningBriefingDisabled", "YES"]
    }

    func testActivityComponentsRecordedHistoryAndDetail() {
        navigateToActivity()

        let headerDetail = app.buttons[AXID.activityHeroReadiness].firstMatch
        let footerDetail = app.buttons["activity-hero-details"].firstMatch
        let ring = waitForElement("activity-hero-ring", timeout: 15)
        let components = waitForElement("activity-hero-components", timeout: 15)
        let trend = waitForElement("activity-hero-trend", timeout: 15)
        XCTAssertTrue(headerDetail.waitForExistence(timeout: 10), "Existing readiness header action remains available")
        XCTAssertTrue(footerDetail.waitForExistence(timeout: 10), "Readiness details CTA should be available")
        XCTAssertFalse(ring.label.isEmpty, "Readiness ring must speak its current score")
        XCTAssertTrue(components.debugDescription.localizedCaseInsensitiveContains("HRV"),
                      "The component group should expose HRV")
        XCTAssertTrue(components.debugDescription.localizedCaseInsensitiveContains("sleep")
                      || components.debugDescription.contains("수면")
                      || components.debugDescription.contains("睡眠"),
                      "The component group should expose sleep")
        assertRecordedTrend(trend, identifier: "activity-hero-trend",
                            entries: [(5, "82"), (2, "68")], title: "Activity")

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-hero-details", maxSwipes: 3),
                      "Readiness detail action should remain reachable")
        footerDetail.tap()
        XCTAssertTrue(waitForElement(AXID.activityTrainingReadinessDetailScreen, timeout: 10).exists,
                      "The original readiness destination should open")
    }

    func testLifeSummaryRecordedCompletionsAndChecklist() {
        navigateToLife()

        let ring = waitForElement("life-hero-ring", timeout: 15)
        let narrative = waitForElement("life-hero-narrative", timeout: 15)
        let summary = waitForElement("life-hero-summary", timeout: 15)
        let trend = waitForElement("life-hero-trend", timeout: 15)
        XCTAssertFalse(ring.label.isEmpty, "Life ring must speak current progress")
        XCTAssertFalse(narrative.label.isEmpty, "Life hero must explain current status")
        for value in ["1", "2", "3"] {
            XCTAssertTrue(summary.staticTexts.matching(NSPredicate(format: "label == %@", value)).firstMatch.exists,
                          "Completed, remaining, and target counts should be accessible: \(value)")
        }
        assertRecordedTrend(trend, identifier: "life-hero-trend",
                            entries: [(3, "1"), (1, "2")], title: "Life")

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-hero-checklist-button", maxSwipes: 3),
                      "Checklist action should remain reachable below history")
        app.buttons["life-hero-checklist-button"].firstMatch.tap()
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.lifeSectionHabits, maxSwipes: 4),
                      "Checklist action should bring the habit list into view")
    }

    func testSparseHistoryExplainsMissingActivityAndLifeData() {
        var configuration = launchConfiguration
        configuration.additionalArguments.removeAll { $0 == "--ui-hero-rhythm-fixtures" }
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 10))

        navigateToActivity()
        let activityTrend = waitForElement("activity-hero-trend", timeout: 15)
        assertSparseExplanation(activityTrend, title: "Activity")

        navigateToLife()
        let lifeTrend = waitForElement("life-hero-trend", timeout: 15)
        assertSparseExplanation(lifeTrend, title: "Life")
    }

    func testCaptureA01KoreanHero() {
        captureHero(tab: "Activity", root: AXID.activityHeroReadiness,
                    trend: "activity-hero-trend", mapID: "A01", style: "light", maximumAX: false)
    }

    func testCaptureL01KoreanHero() {
        captureHero(tab: "Life", root: AXID.lifeHeroProgress,
                    trend: "life-hero-trend", mapID: "L01", style: "light", maximumAX: false)
    }

    func testCaptureA01KoreanDarkHero() {
        captureHero(tab: "Activity", root: AXID.activityHeroReadiness,
                    trend: "activity-hero-trend", mapID: "A01", style: "dark", maximumAX: false)
    }

    func testCaptureL01KoreanDarkHero() {
        captureHero(tab: "Life", root: AXID.lifeHeroProgress,
                    trend: "life-hero-trend", mapID: "L01", style: "dark", maximumAX: false)
    }

    func testCaptureA01KoreanDarkMaximumAXHero() {
        captureHero(tab: "Activity", root: AXID.activityHeroReadiness,
                    trend: "activity-hero-trend", mapID: "A01", style: "dark", maximumAX: true)
    }

    func testCaptureL01KoreanDarkMaximumAXHero() {
        captureHero(tab: "Life", root: AXID.lifeHeroProgress,
                    trend: "life-hero-trend", mapID: "L01", style: "dark", maximumAX: true)
    }

    private func assertRecordedTrend(_ trend: XCUIElement, identifier: String,
                                     entries: [(daysAgo: Int, value: String)], title: String) {
        for index in 0..<7 {
            let day = trend.descendants(matching: .any)["\(identifier)-day-\(index)"].firstMatch
            XCTAssertTrue(day.waitForExistence(timeout: 5),
                          "\(title) should expose each of the seven calendar days: \(index)")
            let date = Calendar.current.date(byAdding: .day, value: index - 6, to: Date()) ?? Date()
            let dayLabel = date.formatted(.dateTime.month(.abbreviated).day())
            XCTAssertTrue(day.label.contains(dayLabel),
                          "\(title) day \(index) should expose \(dayLabel) in AX")
        }
        for entry in entries {
            let day = trend.descendants(matching: .any)["\(identifier)-day-\(6 - entry.daysAgo)"].firstMatch
            let value = entry.value
            let spokenValue = day.label + " " + String(describing: day.value)
            XCTAssertTrue(spokenValue.contains(value),
                          "\(title) trend should expose recorded value \(value) on the correct day")
        }
    }

    private func assertSparseExplanation(_ trend: XCUIElement, title: String) {
        let hierarchy = trend.debugDescription
        let messages = [
            "Not enough data to show trend.",
            "추이를 보여줄 데이터가 부족합니다.",
            "トレンドを表示するにはデータが不足しています。"
        ]
        XCTAssertTrue(messages.contains { hierarchy.contains($0) },
                      "\(title) should explain sparse recorded history")
    }

    private func captureHero(tab: String, root: String, trend: String, mapID: String,
                             style: String, maximumAX: Bool) {
        let category = maximumAX ? "UICTContentSizeCategoryAccessibilityXXXL" : nil
        var configuration = launchConfiguration
        configuration.initialTabSelectionArgument = tab == "Activity" ? "train" : "life"
        configuration.additionalArguments += [
            "--ui-test-style", style,
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR"
        ]
        if let category {
            configuration.additionalArguments += ["-UIPreferredContentSizeCategoryName", category]
        }
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        if tab == "Activity" { navigateToActivity() } else { navigateToLife() }

        let size = category == nil ? "Default" : "MaxAX"
        let name = "\(mapID)-\(style)-ko-\(size)"
        XCTAssertTrue(waitForElement(root, timeout: 15).exists)
        capture(name + "-overview")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(trend, maxSwipes: 4),
                      "\(name): recorded trend should remain visible after scrolling")
        XCTAssertTrue(waitForElement(trend, timeout: 5).exists)
        capture(name + "-history")
    }

    private func capture(_ name: String) {
        if VisualAudit.isEnabled {
            VisualAudit.capture(name)
        } else {
            addScreenshotAttachment(named: name)
        }
    }
}
