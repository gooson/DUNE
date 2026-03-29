@preconcurrency import XCTest

/// Smoke tests for the Sleep Detail screen (MetricDetailView, category: .sleep).
/// Verifies the 4 SectionGroup sections render with correct accessibility identifiers.
@MainActor
final class SleepDetailSmokeTests: SeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US"
        ]
    }

    /// Navigate to sleep metric detail from Dashboard.
    private func navigateToSleepDetail() {
        navigateToDashboard()

        let sleepCard = app.descendants(matching: .any)[AXID.dashboardMetricCard("sleep")].firstMatch
        guard sleepCard.waitForExistence(timeout: 10) else {
            XCTFail("Sleep metric card should exist on Dashboard")
            return
        }

        // Scroll to the sleep card if needed and tap
        _ = app.scrollToElementIfNeeded(AXID.dashboardMetricCard("sleep"), maxSwipes: 6)
        sleepCard.tap()

        let detailScreen = app.descendants(matching: .any)[AXID.metricDetailScreen("sleep")].firstMatch
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10), "Sleep detail screen should appear")
    }

    // MARK: - Section Group Existence

    func testSleepQualitySectionExists() throws {
        navigateToSleepDetail()

        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.sleepSectionQuality, maxSwipes: 4),
            "Sleep Quality section should be reachable by scrolling"
        )
        XCTAssertTrue(
            elementExists(AXID.sleepSectionQuality),
            "Sleep Quality SectionGroup should exist"
        )
    }

    func testSleepPatternsSectionExists() throws {
        navigateToSleepDetail()

        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.sleepSectionPatterns, maxSwipes: 6),
            "Sleep Patterns section should be reachable by scrolling"
        )
        XCTAssertTrue(
            elementExists(AXID.sleepSectionPatterns),
            "Sleep Patterns SectionGroup should exist"
        )
    }

    func testNocturnalHealthSectionExists() throws {
        navigateToSleepDetail()

        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.sleepSectionNocturnal, maxSwipes: 8),
            "Nocturnal Health section should be reachable by scrolling"
        )
        XCTAssertTrue(
            elementExists(AXID.sleepSectionNocturnal),
            "Nocturnal Health SectionGroup should exist"
        )
    }

    func testExternalFactorsSectionExists() throws {
        navigateToSleepDetail()

        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.sleepSectionExternal, maxSwipes: 10),
            "External Factors section should be reachable by scrolling"
        )
        XCTAssertTrue(
            elementExists(AXID.sleepSectionExternal),
            "External Factors SectionGroup should exist"
        )
    }
}
