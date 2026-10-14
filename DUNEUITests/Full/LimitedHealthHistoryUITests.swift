@preconcurrency import XCTest

@MainActor
final class LimitedHealthHistoryUITests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "today" }
    override var additionalLaunchArguments: [String] {
        ["--uitest-limited-health-history", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToDashboard()
    }

    func testConditionDetailExplainsLimitedHistory() {
        dismissMorningBriefingIfNeeded()
        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.descendants(matching: .any)["limited-health-history-notice"].firstMatch
                .waitForExistence(timeout: 10),
            "The dashboard explains limited history even when a score is ready"
        )
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("limited-health-history-notice"))
        capture("Today with limited HealthKit history")
        hero.auditTap()

        let detail = app.descendants(matching: .any)[AXID.conditionScoreDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.descendants(matching: .any)["limited-health-history-notice"].firstMatch
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("limited-health-history-notice"))
        capture("Condition detail with limited HealthKit history")
    }

    func testMetricDetailExplainsLimitedHistory() {
        dismissMorningBriefingIfNeeded()
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.dashboardMetricCard("hrv")))
        let card = app.descendants(matching: .any)[AXID.dashboardMetricCard("hrv")].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.auditTap()

        let detail = app.descendants(matching: .any)[AXID.metricDetailScreen("hrv")].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.descendants(matching: .any)["limited-health-history-notice"].firstMatch
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("limited-health-history-notice"))
        capture("HRV detail with limited HealthKit history")
    }

    func testAllDataExplainsLimitedHistory() {
        dismissMorningBriefingIfNeeded()
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.dashboardMetricCard("hrv")))
        let card = app.descendants(matching: .any)[AXID.dashboardMetricCard("hrv")].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.metricDetailScreen("hrv")].firstMatch
                .waitForExistence(timeout: 8)
        )

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.metricDetailShowAllData))
        app.descendants(matching: .any)[AXID.metricDetailShowAllData].firstMatch.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)["all-data-screen-hrv"].firstMatch
                .waitForExistence(timeout: 8)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["limited-health-history-notice"].firstMatch
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("limited-health-history-notice"))
        capture("HRV all data with limited HealthKit history")
    }

    private func dismissMorningBriefingIfNeeded() {
        let briefing = app.descendants(matching: .any)[AXID.dashboardMorningBriefingScreen].firstMatch
        let dismiss = app.descendants(matching: .any)[AXID.dashboardMorningBriefingDismiss].firstMatch
        let deadline = Date().addingTimeInterval(5)

        while Date() < deadline {
            if dismiss.waitForExistence(timeout: 0.25) {
                dismiss.auditTap()
                let dismissed = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == false"), object: briefing
                )
                XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
                return
            }
            if !briefing.exists { return }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        XCTAssertFalse(briefing.exists, "Morning Briefing should dismiss before limited-history checks")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        VisualAudit.capture(name)
    }
}
