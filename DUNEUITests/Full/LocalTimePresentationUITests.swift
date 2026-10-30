@preconcurrency import XCTest

@MainActor
final class LocalTimePresentationUITests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "today" }
    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--ui-dashboard-hour", "0",
         "-lastBriefingDate", "1900-01-01", "-morningBriefingDisabled", "NO"]
    }

    func testMidnightInsightAndLateMorningBriefing() throws {
        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        let briefing = app.descendants(matching: .any)[AXID.dashboardMorningBriefingScreen].firstMatch
        XCTAssertFalse(briefing.exists, "Midnight must not auto-present the morning briefing")
        captureLocalTimeState("T03 local midnight")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("dashboard-insight-night-rest", maxSwipes: 8))
        XCTAssertFalse(app.staticTexts["Great weather for outdoor exercise"].exists)
        captureLocalTimeState("T03 local midnight insights")
        let scroll = app.scrollViews["dashboard-root-scroll"].firstMatch
        for _ in 0..<8 where !hero.isHittable { scroll.swipeDown() }
        XCTAssertTrue(hero.isHittable)
        hero.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.conditionScoreDetailScreen].firstMatch.waitForExistence(timeout: 8))
        let nightGuidance = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Wind down for a restful night")).firstMatch
        XCTAssertTrue(nightGuidance.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Good Morning"].exists)
        captureLocalTimeState("T04 local midnight insight")

        var configuration = launchConfiguration
        let index = try XCTUnwrap(configuration.additionalArguments.firstIndex(of: "--ui-dashboard-hour"))
        configuration.additionalArguments[index + 1] = "11"
        launchApp(with: configuration)
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertFalse(briefing.exists, "11:00 is outside the morning greeting window")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("briefing-entry-card", maxSwipes: 8))
        app.descendants(matching: .any)["briefing-entry-card"].firstMatch.auditTap()
        XCTAssertTrue(briefing.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Morning Briefing"].exists)
        XCTAssertFalse(app.navigationBars["Good Morning"].exists)
        captureLocalTimeState("T09 local 11 manual briefing")
    }

    func testMorningBriefingAtSix() throws {
        var configuration = launchConfiguration
        let index = try XCTUnwrap(configuration.additionalArguments.firstIndex(of: "--ui-dashboard-hour"))
        configuration.additionalArguments[index + 1] = "6"
        launchApp(with: configuration)
        let briefing = app.descendants(matching: .any)[AXID.dashboardMorningBriefingScreen].firstMatch
        XCTAssertTrue(briefing.waitForExistence(timeout: 15))
        XCTAssertTrue(app.navigationBars["Good Morning"].exists)
        captureLocalTimeState("T09 local 06 morning briefing")
    }

    private func captureLocalTimeState(_ name: String) {
        addScreenshotAttachment(named: name)
        // Duo's active inner display needs the existing host-side native capture handshake.
        VisualAudit.capture(name)
    }
}
