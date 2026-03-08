@preconcurrency import XCTest

/// Regression coverage for chart long-press vs period/selection interaction.
@MainActor
final class ChartInteractionRegressionUITests: SeededUITestBaseCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToActivity()
    }

    func testWeeklyStatsLongPressKeepsPeriodAndActivatesSelection() throws {
        let readinessHero = waitForElement(AXID.activityHeroReadiness, timeout: 15)
        XCTAssertTrue(readinessHero.exists, "Activity tab should be visible before opening weekly stats")
        let weeklyStatsSection = waitForElement(AXID.activitySectionWeeklyStats, timeout: 15)
        weeklyStatsSection.tap()

        let periodPicker = waitForElement(AXID.weeklyStatsPeriodPicker, timeout: 15)
        let initialPeriod = periodPicker.value as? String

        let chart = waitForElement(AXID.weeklyStatsChartDailyVolume, timeout: 15)
        let selectionProbe = waitForElement(AXID.chartSelectionProbe, timeout: 10)
        XCTAssertEqual(selectionProbe.label, "none", "Selection probe should be empty before the gesture")

        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.55))
        start.press(forDuration: 0.45, thenDragTo: end)

        XCTAssertEqual(
            periodPicker.value as? String,
            initialPeriod,
            "Long press selection should not change the weekly stats period"
        )
        XCTAssertNotEqual(
            selectionProbe.label,
            "none",
            "Long press selection should update the chart selection probe"
        )
        XCTAssertTrue(chart.exists, "Weekly stats chart should remain visible after long press selection")
    }
}
