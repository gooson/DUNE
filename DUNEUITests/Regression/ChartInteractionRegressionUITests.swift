@preconcurrency import XCTest

/// Regression coverage for chart long-press vs period/selection interaction.
@MainActor
final class ChartInteractionRegressionUITests: SeededUITestBaseCase {
    func testRHRDetailChartScrollsToPastData() throws {
        openDashboardMetricDetail("rhr")
        assertDetailChartScrollsToPastData(category: "rhr")
    }

    func testSleepDetailChartScrollsToPastData() throws {
        openDashboardMetricDetail("sleep")
        assertDetailChartScrollsToPastData(category: "sleep")
    }

    func testStepsDetailChartScrollsToPastData() throws {
        openDashboardMetricDetail("steps")
        assertDetailChartScrollsToPastData(category: "steps")
    }

    func testWeightDetailChartScrollsToPastData() throws {
        navigateToWellness()

        let weightCard = waitForElement(AXID.wellnessCardWeight, timeout: 15)
        weightCard.tap()

        assertDetailChartScrollsToPastData(category: "weight")
    }

    func testWeeklyStatsLongPressKeepsPeriodAndActivatesSelection() throws {
        openWeeklyStatsDetail()

        let periodPicker = waitForElement(AXID.weeklyStatsPeriodPicker, timeout: 15)
        let initialPeriod = periodPicker.value as? String

        let chart = waitForElement(AXID.weeklyStatsChartDailyVolume, timeout: 15)
        let selectionProbe = waitForElement(AXID.chartSelectionProbe, timeout: 10)
        let initialRange = visibleRangeValue(of: chart)
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
        XCTAssertEqual(
            visibleRangeValue(of: chart),
            initialRange,
            "Long press selection should not move the visible weekly stats range"
        )
        XCTAssertTrue(chart.exists, "Weekly stats chart should remain visible after long press selection")
    }

    func testWeeklyStatsChartScrollsToPastData() throws {
        openWeeklyStatsDetail()

        let chart = waitForElement(AXID.weeklyStatsChartDailyVolume, timeout: 15)
        let initialRange = visibleRangeValue(of: chart)

        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: end)

        if visibleRangeValue(of: chart) == initialRange {
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        XCTAssertNotEqual(
            visibleRangeValue(of: chart),
            initialRange,
            "Quick horizontal drag should reveal older daily volume data"
        )
    }

    func testTrainingVolumeTrainingLoadChartScrollsToPastData() throws {
        openTrainingVolumeDetail()

        let chart = trainingVolumeChart()
        let initialRange = visibleRangeValue(of: chart)

        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: end)

        if visibleRangeValue(of: chart) == initialRange {
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        XCTAssertNotEqual(
            visibleRangeValue(of: chart),
            initialRange,
            "Quick horizontal drag should reveal older training load data"
        )
    }

    func testTrainingVolumeDailyVolumeChartScrollsToPastData() throws {
        openTrainingVolumeDetail()

        let chart = trainingVolumeDailyVolumeChart()
        let initialRange = visibleRangeValue(of: chart)

        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: end)

        if visibleRangeValue(of: chart) == initialRange {
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        XCTAssertNotEqual(
            visibleRangeValue(of: chart),
            initialRange,
            "Quick horizontal drag should reveal older daily volume data"
        )
    }

    func testTrainingVolumeTrainingLoadLongPressKeepsVisibleRangeAndActivatesSelection() throws {
        openTrainingVolumeDetail()

        let chart = trainingVolumeChart()
        let selectionProbe = waitForElement(AXID.chartSelectionProbe, timeout: 10)
        let initialRange = visibleRangeValue(of: chart)
        XCTAssertEqual(selectionProbe.label, "none", "Selection probe should be empty before long press")

        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.55))
        start.press(forDuration: 0.45, thenDragTo: end)

        XCTAssertEqual(
            visibleRangeValue(of: chart),
            initialRange,
            "Long press selection should not move the training load visible range"
        )
        XCTAssertNotEqual(
            selectionProbe.label,
            "none",
            "Long press selection should update the training load selection probe"
        )
    }

    func testHRVDetailChartScrollsToPastData() throws {
        navigateToWellness()

        let hrvCard = waitForElement(AXID.wellnessCardHRV, timeout: 15)
        hrvCard.tap()

        assertDetailChartScrollsToPastData(category: "hrv")
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

    func testHRVDetailLongPressSelectionDoesNotScrollVisibleRange() throws {
        navigateToWellness()

        let hrvCard = waitForElement(AXID.wellnessCardHRV, timeout: 15)
        hrvCard.tap()

        let detailScreen = waitForElement(AXID.metricDetailScreen("hrv"), timeout: 15)
        XCTAssertTrue(detailScreen.exists, "HRV detail should open from the Wellness card")

        let visibleRange = waitForElement(AXID.detailChartVisibleRange, timeout: 15)
        let chart = waitForElement(AXID.detailChartSurface, timeout: 15)
        let initialRange = visibleRange.label

        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.68, dy: 0.55))
        start.press(forDuration: 0.45, thenDragTo: end)

        XCTAssertEqual(
            visibleRange.label,
            initialRange,
            "Long press selection should not scroll the chart visible range while inspecting values"
        )
    }

    func testHRVDetailQuickDragScrollsWithoutActivatingSelection() throws {
        navigateToWellness()

        let hrvCard = waitForElement(AXID.wellnessCardHRV, timeout: 15)
        hrvCard.tap()

        let detailScreen = waitForElement(AXID.metricDetailScreen("hrv"), timeout: 15)
        XCTAssertTrue(detailScreen.exists, "HRV detail should open from the Wellness card")

        let visibleRange = waitForElement(AXID.detailChartVisibleRange, timeout: 15)
        let chart = waitForElement(AXID.detailChartSurface, timeout: 15)
        let selectionProbe = waitForElement(AXID.chartSelectionProbe, timeout: 10)
        let initialRange = visibleRange.label
        XCTAssertEqual(selectionProbe.label, "none", "Selection probe should be empty before quick drag")

        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: end)

        if visibleRange.label == initialRange {
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        XCTAssertNotEqual(
            visibleRange.label,
            initialRange,
            "Quick horizontal drag should still scroll the chart to older data"
        )
        XCTAssertEqual(
            selectionProbe.label,
            "none",
            "Quick drag should not accidentally activate chart selection"
        )
    }

    func testHRVDetailChartScrollResumesAfterLongPressEnds() throws {
        navigateToWellness()

        let hrvCard = waitForElement(AXID.wellnessCardHRV, timeout: 15)
        hrvCard.tap()

        let detailScreen = waitForElement(AXID.metricDetailScreen("hrv"), timeout: 15)
        XCTAssertTrue(detailScreen.exists, "HRV detail should open from the Wellness card")

        let visibleRange = waitForElement(AXID.detailChartVisibleRange, timeout: 15)
        let chart = waitForElement(AXID.detailChartSurface, timeout: 15)

        let selectionStart = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.55))
        let selectionEnd = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.55))
        selectionStart.press(forDuration: 0.45, thenDragTo: selectionEnd)

        let rangeAfterSelection = visibleRange.label
        let scrollStart = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.55))
        let scrollEnd = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.55))
        scrollStart.press(forDuration: 0.05, thenDragTo: scrollEnd)

        if visibleRange.label == rangeAfterSelection {
            scrollStart.press(forDuration: 0.05, thenDragTo: scrollEnd)
        }

        XCTAssertNotEqual(
            visibleRange.label,
            rangeAfterSelection,
            "Chart should resume horizontal scrolling immediately after long press selection ends"
        )
    }

    func testHRVDetailScrollAfterSelectionClearsOverlayAndDoesNotSnapBack() throws {
        navigateToWellness()

        let hrvCard = waitForElement(AXID.wellnessCardHRV, timeout: 15)
        hrvCard.tap()

        let detailScreen = waitForElement(AXID.metricDetailScreen("hrv"), timeout: 15)
        XCTAssertTrue(detailScreen.exists, "HRV detail should open from the Wellness card")

        let visibleRange = waitForElement(AXID.detailChartVisibleRange, timeout: 15)
        let chart = waitForElement(AXID.detailChartSurface, timeout: 15)

        let firstSelectionStart = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.55))
        let firstSelectionEnd = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.55))
        firstSelectionStart.press(forDuration: 0.45, thenDragTo: firstSelectionEnd)

        let scrollStart = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.55))
        let scrollEnd = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.55))
        scrollStart.press(forDuration: 0.05, thenDragTo: scrollEnd)

        if app.descendants(matching: .any)[AXID.chartSelectionOverlay].firstMatch.exists {
            scrollStart.press(forDuration: 0.05, thenDragTo: scrollEnd)
        }

        let rangeAfterScroll = visibleRange.label
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.chartSelectionOverlay].firstMatch.waitForNonExistence(timeout: 2),
            "Scrolling after selection should clear any stale chart overlay"
        )

        let secondSelectionStart = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.46, dy: 0.55))
        let secondSelectionEnd = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.55))
        secondSelectionStart.press(forDuration: 0.45, thenDragTo: secondSelectionEnd)

        XCTAssertEqual(
            visibleRange.label,
            rangeAfterScroll,
            "A new long press should not restore the previous visible month after scrolling"
        )
    }

    func testHRVDetailScreenVerticalScrollWorksFromChartSurface() throws {
        navigateToWellness()

        let hrvCard = waitForElement(AXID.wellnessCardHRV, timeout: 15)
        hrvCard.tap()

        let detailScreen = waitForElement(AXID.metricDetailScreen("hrv"), timeout: 15)
        XCTAssertTrue(detailScreen.exists, "HRV detail should open from the Wellness card")

        let chart = waitForElement(AXID.detailChartSurface, timeout: 15)
        let showAllData = waitForElement(AXID.metricDetailShowAllData, timeout: 15)

        if !showAllData.isHittable {
            let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.78))
            let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.12))
            start.press(forDuration: 0.05, thenDragTo: end)

            if !showAllData.isHittable {
                start.press(forDuration: 0.05, thenDragTo: end)
            }
        }

        XCTAssertTrue(
            showAllData.isHittable,
            "Vertical drag starting on the chart should still scroll the detail screen"
        )
    }

    private func openDashboardMetricDetail(_ category: String) {
        navigateToDashboard()

        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.dashboardMetricCard(category), maxSwipes: 6),
            "Dashboard metric card for \(category) should be reachable in seeded state"
        )

        let card = waitForElement(AXID.dashboardMetricCard(category), timeout: 15)
        card.tap()
    }

    private func openWeeklyStatsDetail() {
        navigateToActivity()

        let readinessHero = waitForElement(AXID.activityHeroReadiness, timeout: 15)
        XCTAssertTrue(readinessHero.exists, "Activity tab should be visible before opening weekly stats")

        let weeklyStatsSection = waitForElement(AXID.activitySectionWeeklyStats, timeout: 15)
        weeklyStatsSection.tap()

        let detailScreen = waitForElement(AXID.activityWeeklyStatsDetailScreen, timeout: 15)
        XCTAssertTrue(detailScreen.exists, "Weekly stats detail should open from the Activity tab")
    }

    private func openTrainingVolumeDetail() {
        navigateToActivity()

        let readinessHero = waitForElement(AXID.activityHeroReadiness, timeout: 15)
        XCTAssertTrue(readinessHero.exists, "Activity tab should be visible before opening training volume")
        waitForElement(AXID.activitySectionVolume, timeout: 15).tap()

        let detailScreen = waitForElement(AXID.activityTrainingVolumeDetailScreen, timeout: 15)
        XCTAssertTrue(detailScreen.exists, "Training volume detail should open from the Activity tab")
    }

    private func trainingVolumeChart() -> XCUIElement {
        let chart = waitForElement(AXID.trainingVolumeChartTrainingLoad, timeout: 15)
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.trainingVolumeChartTrainingLoad, maxSwipes: 6),
            "Training load chart should be on-screen before chart gestures"
        )
        return chart
    }

    private func trainingVolumeDailyVolumeChart() -> XCUIElement {
        let chart = waitForElement(AXID.trainingVolumeChartDailyVolume, timeout: 15)
        XCTAssertTrue(chart.exists, "Training volume daily volume chart should be visible on the detail screen")
        return chart
    }

    private func assertDetailChartScrollsToPastData(category: String) {
        let detailScreen = waitForElement(AXID.metricDetailScreen(category), timeout: 15)
        XCTAssertTrue(detailScreen.exists, "\(category) detail should open from seeded navigation")

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
            "Horizontal drag on the \(category) chart should reveal an older visible range"
        )
    }

    private func visibleRangeValue(of element: XCUIElement) -> String {
        element.value as? String ?? ""
    }
}
