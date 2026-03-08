@preconcurrency import XCTest

/// Regression coverage for chart long-press vs period/selection interaction.
@MainActor
final class ChartInteractionRegressionUITests: SeededUITestBaseCase {
    func testWeeklyStatsLongPressKeepsPeriodAndActivatesSelection() throws {
        navigateToActivity()

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

    func testHRVDetailChartScrollsToPastData() throws {
        navigateToWellness()

        let hrvCard = waitForElement(AXID.wellnessCardHRV, timeout: 15)
        hrvCard.tap()

        let detailScreen = waitForElement(AXID.metricDetailScreen("hrv"), timeout: 15)
        XCTAssertTrue(detailScreen.exists, "HRV detail should open from the Wellness card")

        let visibleRange = waitForElement(AXID.detailChartVisibleRange, timeout: 15)
        let chart = waitForElement(AXID.detailChartSurface, timeout: 15)
        let initialRange = visibleRange.label

        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: end)

        if visibleRange.label == initialRange {
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        XCTAssertNotEqual(
            visibleRange.label,
            initialRange,
            "Horizontal drag on the HRV chart should reveal an older visible range"
        )
    }

    func testHRVDetailChartLongPressSelectionClearsAfterGesture() throws {
        navigateToWellness()

        let hrvCard = waitForElement(AXID.wellnessCardHRV, timeout: 15)
        hrvCard.tap()

        let detailScreen = waitForElement(AXID.metricDetailScreen("hrv"), timeout: 15)
        XCTAssertTrue(detailScreen.exists, "HRV detail should open from the Wellness card")

        let chart = waitForElement(AXID.detailChartSurface, timeout: 15)
        let selectionProbe = waitForElement(AXID.chartSelectionProbe, timeout: 10)
        XCTAssertEqual(selectionProbe.label, "none", "Selection probe should be empty before long press")

        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.55))
        start.press(forDuration: 0.45, thenDragTo: end)

        XCTAssertNotEqual(
            selectionProbe.label,
            "none",
            "Long press selection should update the chart selection probe"
        )

        let overlay = app.descendants(matching: .any)[AXID.chartSelectionOverlay].firstMatch
        XCTAssertTrue(
            overlay.waitForNonExistence(timeout: 2),
            "Shared detail chart selection overlay should clear after the gesture ends"
        )
    }
}
