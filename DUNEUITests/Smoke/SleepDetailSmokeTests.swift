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
            "en_US"
        ]
    }

    /// Navigate to sleep metric detail from Dashboard.
    private func navigateToSleepDetail() throws {
        navigateToDashboard()

        let cardID = AXID.dashboardMetricCard("sleep")
        guard app.scrollToElementIfNeeded(cardID, maxSwipes: 6) else {
            throw XCTSkip("Sleep metric card not found on Dashboard — may need HealthKit data")
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
}
