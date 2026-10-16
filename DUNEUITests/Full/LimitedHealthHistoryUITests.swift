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
        card.press(forDuration: 1.1)
        let showAllData = app.buttons["Show All Data"].firstMatch
        XCTAssertTrue(showAllData.waitForExistence(timeout: 5))
        showAllData.tap()

        let allData = app.descendants(matching: .any)["all-data-screen-hrv"].firstMatch
        XCTAssertTrue(allData.waitForExistence(timeout: 8))
        XCTAssertTrue(allData.isHittable, "All Data must be in the foreground, not behind Metric Detail")
        XCTAssertTrue(
            app.descendants(matching: .any)["limited-health-history-notice"].firstMatch
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("limited-health-history-notice"))
        capture("HRV all data with limited HealthKit history")
    }

    func testMetricComparisonExplainsLimitedHistory() {
        navigateToWellness()
        XCTAssertTrue(app.waitAndTapToolbarAction("wellness-compare-metrics"))

        let firstPane = app.descendants(matching: .any)["metric-comparison-first"].firstMatch
        XCTAssertTrue(firstPane.waitForExistence(timeout: 8))
        let firstPicker = firstPane.descendants(matching: .any)["metric-comparison-first-picker"].firstMatch
        XCTAssertTrue(firstPicker.waitForExistence(timeout: 5))
        firstPicker.auditTap()

        let hrv = app.descendants(matching: .any)["metric-comparison-first-option-hrv"].firstMatch
        XCTAssertTrue(hrv.waitForExistence(timeout: 5))
        hrv.auditTap()

        let notice = firstPane.descendants(matching: .any)["limited-health-history-notice"].firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("limited-health-history-notice"))
        capture("Metric comparison with limited HealthKit history")
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
        // Navigation transitions can outlive XCTest's idle signal and produce
        // a screenshot of the previous view after the destination is in AX.
        Thread.sleep(forTimeInterval: 0.8)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        VisualAudit.capture(name)
    }
}
