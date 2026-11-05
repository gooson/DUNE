@preconcurrency import XCTest

/// Smoke tests for the Sleep Detail screen (MetricDetailView, category: .sleep).
/// Verifies the 4 SectionGroup sections render with correct accessibility identifiers.
///
/// Requires seeded mock data for the dashboard sleep metric card to be tappable.
/// If the app crashes on launch due to HealthKit permissions, accept them manually
/// and re-run.
@MainActor
final class SleepDetailSmokeTests: UITestBaseCase {
    override var shouldSeedMockData: Bool { true }

    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US",
            "--ui-design-map-sleep-insights"
        ]
    }

    /// Navigate to sleep metric detail from Dashboard.
    private func navigateToSleepDetail() throws {
        navigateToDashboard()

        let cardID = AXID.dashboardMetricCard("sleep")
        let dashboardScroll = app.scrollViews["dashboard-root-scroll"].firstMatch
        guard app.revealFullyVisible(cardID, in: dashboardScroll) else {
            XCTFail("Seeded Sleep metric card must be fully reachable on Dashboard")
            return
        }

        let sleepCard = app.descendants(matching: .any)[cardID].firstMatch
        sleepCard.tap()

        let detailScreen = app.descendants(matching: .any)[AXID.metricDetailScreen("sleep")].firstMatch
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10), "Sleep detail screen should appear")
    }

    // MARK: - Section Group Existence

    func testSleepSectionsExist() throws {
        try navigateToSleepDetail()

        // Group 1: Sleep Quality
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.sleepSectionQuality, maxSwipes: 4),
            "Sleep Quality section should be reachable by scrolling"
        )

        // Group 2: Sleep Patterns
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.sleepSectionPatterns, maxSwipes: 4),
            "Sleep Patterns section should be reachable by scrolling"
        )

        // Group 3: Nocturnal Health
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.sleepSectionNocturnal, maxSwipes: 4),
            "Nocturnal Health section should be reachable by scrolling"
        )

        // Group 4: External Factors
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.sleepSectionExternal, maxSwipes: 4),
            "External Factors section should be reachable by scrolling"
        )
    }

    func testSleepDebtExplanationOpens() throws {
        try navigateToSleepDetail()
        let detailScroll = app.scrollViews[AXID.metricDetailScreen("sleep")].firstMatch
        XCTAssertTrue(app.revealFullyVisible("sleep-debt-info-button", in: detailScroll))
        app.buttons["sleep-debt-info-button"].firstMatch.auditTap()
        let sheet = app.scrollViews["sleep-debt-info-sheet"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        for identifier in [
            "sleep-debt-info-title", "sleep-debt-info-baseline",
            "sleep-debt-info-calculation", "sleep-debt-info-excess"
        ] {
            XCTAssertTrue(app.revealFullyVisible(identifier, in: sheet), "Missing or clipped \(identifier)")
            if identifier != "sleep-debt-info-title" {
                XCTAssertTrue(app.revealTextBody(identifier + "-body", in: sheet),
                              "Missing or clipped \(identifier)-body")
            }
        }
        VisualAudit.capture("H12 sleep debt explanation body")
        XCTAssertTrue(app.revealFullyVisible("sleep-debt-info-levels", in: sheet))
        XCTAssertTrue(app.revealFullyVisible("sleep-debt-info-level-severe", in: sheet))
        VisualAudit.capture("H12 sleep debt explanation levels")
        let close = app.buttons["sleep-debt-info-close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(app.revealFullyVisible("sleep-debt-info-close", in: sheet))
        close.auditTap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5), "Close must return to Sleep detail")
    }

    func testWakeAnalysisExplanationOpens() throws {
        try navigateToSleepDetail()
        XCTAssertTrue(revealSleepInfoButton("sleep-waso-info-button"))
        app.buttons["sleep-waso-info-button"].firstMatch.auditTap()
        XCTAssertTrue(app.scrollViews["sleep-waso-info-sheet"].firstMatch.waitForExistence(timeout: 5))
        VisualAudit.capture("WASO explanation")
    }

    private func revealSleepInfoButton(_ identifier: String) -> Bool {
        let detailScroll = app.scrollViews[AXID.metricDetailScreen("sleep")].firstMatch
        guard detailScroll.waitForExistence(timeout: 5) else { return false }
        let button = app.buttons[identifier].firstMatch
        for _ in 0..<14 where !button.isHittable {
            detailScroll.swipeUp(velocity: .slow)
        }
        return button.isHittable
    }
}
