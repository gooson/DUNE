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
        dismissMorningBriefingIfNeeded()
    }

    func testConditionDetailExplainsLimitedHistory() {
        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        hero.auditTap()

        let detail = app.descendants(matching: .any)[AXID.conditionScoreDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.descendants(matching: .any)["limited-health-history-notice"].firstMatch
                .waitForExistence(timeout: 10)
        )
        capture("Condition detail with limited HealthKit history")
    }

    func testMetricDetailExplainsLimitedHistory() {
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
        capture("HRV detail with limited HealthKit history")
    }

    func testAllDataExplainsLimitedHistory() {
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
        capture("HRV all data with limited HealthKit history")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        VisualAudit.capture(name)
    }
}
