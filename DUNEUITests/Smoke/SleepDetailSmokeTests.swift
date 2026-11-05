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

    func testSleepExplanationSheetsAtMaximumAccessibilityTextSize() throws {
        // Both explanation sheets include 20 host-synchronized capture checkpoints.
        if VisualAudit.isEnabled { executionTimeAllowance = 480 }
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        try navigateToSleepDetail()
        let detailScroll = app.scrollViews[AXID.metricDetailScreen("sleep")].firstMatch

        XCTAssertTrue(app.revealFullyVisible("sleep-debt-info-button", in: detailScroll))
        app.buttons["sleep-debt-info-button"].firstMatch.auditTap()
        let debtSheet = app.scrollViews["sleep-debt-info-sheet"].firstMatch
        XCTAssertTrue(debtSheet.waitForExistence(timeout: 5))
        for identifier in ["sleep-debt-info-title", "sleep-debt-info-baseline",
                           "sleep-debt-info-calculation", "sleep-debt-info-excess",
                           "sleep-debt-info-levels"] {
            XCTAssertTrue(app.revealFullyVisible(identifier, in: debtSheet), "MAX missing or clipped \(identifier)")
            if identifier != "sleep-debt-info-title" && identifier != "sleep-debt-info-levels" {
                XCTAssertTrue(app.revealTextBody(identifier + "-body", in: debtSheet),
                              "MAX missing or clipped \(identifier)-body")
            }
        }
        XCTAssertTrue(app.revealFullyVisible("sleep-debt-info-level-severe", in: debtSheet))
        VisualAudit.capture("H12 MAX sleep debt levels")
        XCTAssertTrue(app.revealFullyVisible("sleep-debt-info-close", in: debtSheet))
        app.buttons["sleep-debt-info-close"].firstMatch.auditTap()
        let debtDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: debtSheet
        )
        XCTAssertEqual(XCTWaiter.wait(for: [debtDismissed], timeout: 5), .completed)
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5))

        XCTAssertTrue(app.revealFullyVisible("sleep-waso-info-button", in: detailScroll))
        app.buttons["sleep-waso-info-button"].firstMatch.auditTap()
        let wasoSheet = app.scrollViews["sleep-waso-info-sheet"].firstMatch
        XCTAssertTrue(wasoSheet.waitForExistence(timeout: 5))
        for identifier in ["sleep-waso-info-title", "sleep-waso-info-definition",
                           "sleep-waso-info-measurement", "sleep-waso-info-scoring",
                           "sleep-waso-info-guide"] {
            XCTAssertTrue(app.revealFullyVisible(identifier, in: wasoSheet), "MAX missing or clipped \(identifier)")
            if identifier != "sleep-waso-info-title" && identifier != "sleep-waso-info-guide" {
                XCTAssertTrue(app.revealTextBody(identifier + "-body", in: wasoSheet),
                              "MAX missing or clipped \(identifier)-body")
            }
        }
        XCTAssertTrue(app.revealFullyVisible("sleep-waso-info-guide-poor", in: wasoSheet))
        VisualAudit.capture("H13 MAX WASO score guide")
        XCTAssertTrue(app.revealFullyVisible("sleep-waso-info-close", in: wasoSheet))
        app.buttons["sleep-waso-info-close"].firstMatch.auditTap()
        let wasoDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: wasoSheet
        )
        XCTAssertEqual(XCTWaiter.wait(for: [wasoDismissed], timeout: 5), .completed)
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5))
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
        let detailScroll = app.scrollViews[AXID.metricDetailScreen("sleep")].firstMatch
        XCTAssertTrue(app.revealFullyVisible("sleep-waso-info-button", in: detailScroll))
        app.buttons["sleep-waso-info-button"].firstMatch.auditTap()
        let sheet = app.scrollViews["sleep-waso-info-sheet"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        for identifier in [
            "sleep-waso-info-title", "sleep-waso-info-definition",
            "sleep-waso-info-measurement", "sleep-waso-info-scoring"
        ] {
            XCTAssertTrue(app.revealFullyVisible(identifier, in: sheet), "Missing or clipped \(identifier)")
            if identifier != "sleep-waso-info-title" {
                XCTAssertTrue(app.revealTextBody(identifier + "-body", in: sheet),
                              "Missing or clipped \(identifier)-body")
            }
        }
        VisualAudit.capture("H13 WASO explanation body")
        XCTAssertTrue(app.revealFullyVisible("sleep-waso-info-guide", in: sheet))
        XCTAssertTrue(app.revealFullyVisible("sleep-waso-info-guide-poor", in: sheet))
        VisualAudit.capture("H13 WASO score guide")
        let close = app.buttons["sleep-waso-info-close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(app.revealFullyVisible("sleep-waso-info-close", in: sheet))
        close.auditTap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5), "Close must return to Sleep detail")
    }
}
