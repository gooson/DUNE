@preconcurrency import XCTest

/// Regression coverage for chart long-press vs period/selection interaction.
@MainActor
final class ChartInteractionRegressionUITests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "train" }

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

        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.wellnessCardWeight, maxSwipes: 6),
            "Weight card should be reachable in seeded Wellness state"
        )
        let weightCard = waitForElement(AXID.wellnessCardWeight, timeout: 15)
        weightCard.tap()

        assertDetailChartScrollsToPastData(category: "weight")
    }

    func testWeeklyStatsLongPressKeepsPeriodAndActivatesSelection() throws {
        openWeeklyStatsDetail()

        let periodPicker = waitForElement(AXID.weeklyStatsPeriodPicker, timeout: 15)
        let initialPeriod = periodPicker.value as? String

        let chart = waitForElement(AXID.weeklyStatsChartDailyVolume, timeout: 15)
        let selectionProbe = waitForElement(AXID.chartSelectionProbe, timeout: 15)
        let initialRange = visibleRangeValue(of: chart)
        XCTAssertEqual(selectionProbe.label, "none", "Selection probe should be empty before the gesture")

        let probeLabel = performLongPressUntilProbeChanges(chart: chart, selectionProbe: selectionProbe)

        XCTAssertEqual(
            periodPicker.value as? String,
            initialPeriod,
            "Long press selection should not change the weekly stats period"
        )
        XCTAssertNotEqual(
            probeLabel,
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
        assertChartVisibleRangeChanges(
            chart,
            failureMessage: "Quick horizontal drag should reveal older daily volume data"
        )
    }

    func testTrainingVolumeTrainingLoadChartScrollsToPastData() throws {
        openTrainingVolumeDetail()

        let chart = trainingVolumeChart()
        assertChartVisibleRangeChanges(
            chart,
            failureMessage: "Quick horizontal drag should reveal older training load data"
        )
    }

    func testTrainingVolumeDailyVolumeChartScrollsToPastData() throws {
        openTrainingVolumeDetail()

        let chart = trainingVolumeDailyVolumeChart()
        assertChartVisibleRangeChanges(
            chart,
            failureMessage: "Quick horizontal drag should reveal older daily volume data"
        )
    }

    func testTrainingVolumeTrainingLoadLongPressKeepsVisibleRangeAndActivatesSelection() throws {
        openTrainingVolumeDetail()

        let chart = trainingVolumeChart()
        let selectionProbe = waitForElement(AXID.trainingVolumeChartTrainingLoadSelectionProbe, timeout: 15)
        let initialRange = visibleRangeValue(of: chart)
        XCTAssertEqual(selectionProbe.label, "none", "Selection probe should be empty before long press")

        let probeLabel = performLongPressUntilProbeChanges(chart: chart, selectionProbe: selectionProbe)

        XCTAssertEqual(
            visibleRangeValue(of: chart),
            initialRange,
            "Long press selection should not move the training load visible range"
        )
        XCTAssertNotEqual(
            probeLabel,
            "none",
            "Long press selection should update the training load selection probe"
        )
    }

    func testHRVDetailChartScrollsToPastData() throws {
        openWellnessMetricDetail(AXID.wellnessCardHRV)
        assertDetailChartScrollsToPastData(category: "hrv")
    }

    func testHRVDetailChartLongPressSelectionClearsAfterGesture() throws {
        openWellnessMetricDetail(AXID.wellnessCardHRV)
        let detailScreen = waitForElement(AXID.metricDetailScreen("hrv"), timeout: 15)
        XCTAssertTrue(detailScreen.exists, "HRV detail should open from the Wellness card")

        let chart = waitForElement(AXID.detailChartSurface, timeout: 15)
        let selectionProbe = waitForElement(AXID.chartSelectionProbe, timeout: 15)
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
        openWellnessMetricDetail(AXID.wellnessCardHRV)
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
        openWellnessMetricDetail(AXID.wellnessCardHRV)
        let detailScreen = waitForElement(AXID.metricDetailScreen("hrv"), timeout: 15)
        XCTAssertTrue(detailScreen.exists, "HRV detail should open from the Wellness card")

        let visibleRange = waitForElement(AXID.detailChartVisibleRange, timeout: 15)
        let chart = waitForElement(AXID.detailChartSurface, timeout: 15)
        let selectionProbe = waitForElement(AXID.chartSelectionProbe, timeout: 15)
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
        openWellnessMetricDetail(AXID.wellnessCardHRV)
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
        openWellnessMetricDetail(AXID.wellnessCardHRV)
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
        openWellnessMetricDetail(AXID.wellnessCardHRV)
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
        dismissMorningBriefingIfNeeded()

        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.dashboardMetricCard(category), maxSwipes: 12),
            "Dashboard metric card for \(category) should be reachable in seeded state"
        )

        let card = waitForElement(AXID.dashboardMetricCard(category), timeout: 15)
        card.tap()
    }

    private func openWellnessMetricDetail(_ cardIdentifier: String) {
        navigateToWellness()
        let card = app.descendants(matching: .any)[cardIdentifier].firstMatch
        var reachedCard = false

        for _ in 0..<6 {
            dismissMorningBriefingIfNeeded(timeout: 1.5)
            if card.waitForExistence(timeout: 1) {
                reachedCard = true
                break
            }

            let scrollView = app.scrollViews.firstMatch
            if scrollView.waitForExistence(timeout: 1) {
                scrollView.swipeUp()
            }
        }

        XCTAssertTrue(reachedCard || card.exists, "\(cardIdentifier) should be reachable in seeded Wellness state")
        card.tap()
    }

    private func dismissMorningBriefingIfNeeded(timeout: TimeInterval = 5) {
        let briefingScreen = app.descendants(matching: .any)[AXID.dashboardMorningBriefingScreen].firstMatch
        let dismissButton = app.descendants(matching: .any)[AXID.dashboardMorningBriefingDismiss].firstMatch
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if dismissButton.waitForExistence(timeout: 0.25) {
                dismissButton.tap()

                let predicate = NSPredicate(format: "exists == false")
                let expectation = XCTNSPredicateExpectation(predicate: predicate, object: briefingScreen)
                XCTAssertEqual(
                    XCTWaiter.wait(for: [expectation], timeout: 5),
                    .completed,
                    "Morning Briefing should dismiss before opening metric detail flows"
                )
                return
            }

            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        guard !briefingScreen.exists else {
            XCTFail("Morning Briefing remained visible without exposing a dismiss button")
            return
        }
    }

    private func openWeeklyStatsDetail() {
        let readinessHero = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        for _ in 0..<2 {
            navigateToActivity()
            dismissMorningBriefingIfNeeded(timeout: 1.5)
            if readinessHero.waitForExistence(timeout: 15) {
                break
            }
        }

        XCTAssertTrue(readinessHero.exists, "Activity tab should be visible before opening weekly stats")

        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.activitySectionWeeklyStats, maxSwipes: 6),
            "Weekly stats section should be reachable before opening detail"
        )
        let weeklyStatsSection = waitForElement(AXID.activitySectionWeeklyStats, timeout: 15)
        weeklyStatsSection.tap()

        let detailScreen = waitForElement(AXID.activityWeeklyStatsDetailScreen, timeout: 15)
        XCTAssertTrue(detailScreen.exists, "Weekly stats detail should open from the Activity tab")
    }

    private func openTrainingVolumeDetail() {
        let readinessHero = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        for _ in 0..<2 {
            navigateToActivity()
            dismissMorningBriefingIfNeeded(timeout: 1.5)
            if readinessHero.waitForExistence(timeout: 15) {
                break
            }
        }

        XCTAssertTrue(readinessHero.exists, "Activity tab should be visible before opening training volume")
        let volumeSection = waitForElement(AXID.activitySectionVolume, timeout: 15)
        XCTAssertTrue(
            scrollUntilHittable(volumeSection, maxSwipes: 8),
            "Training volume section should be reachable before opening detail"
        )
        let detailScreen = app.descendants(matching: .any)[AXID.activityTrainingVolumeDetailScreen].firstMatch

        for attempt in 0..<2 {
            volumeSection.tap()
            if detailScreen.waitForExistence(timeout: attempt == 0 ? 10 : 15) {
                XCTAssertTrue(detailScreen.exists, "Training volume detail should open from the Activity tab")
                return
            }

            XCTAssertTrue(
                scrollUntilHittable(volumeSection, maxSwipes: 3),
                "Training volume section should remain tappable while retrying detail navigation"
            )
        }

        XCTFail("Training volume detail should open from the Activity tab")
    }

    private func trainingVolumeChart() -> XCUIElement {
        let chart = waitForElement(AXID.trainingVolumeChartTrainingLoad, timeout: 15)
        XCTAssertTrue(
            scrollTrainingVolumeDetailUntilHittable(chart, maxSwipes: 6),
            "Training load chart should be on-screen before chart gestures"
        )
        return chart
    }

    private func trainingVolumeDailyVolumeChart() -> XCUIElement {
        let chart = waitForElement(AXID.trainingVolumeChartDailyVolume, timeout: 15)
        XCTAssertTrue(
            scrollTrainingVolumeDetailUntilHittable(chart, maxSwipes: 6),
            "Training volume daily volume chart should be on-screen before chart gestures"
        )
        return chart
    }

    private func scrollTrainingVolumeDetailUntilHittable(
        _ element: XCUIElement,
        maxSwipes: Int
    ) -> Bool {
        scrollUntilHittable(
            element,
            maxSwipes: maxSwipes,
            scrollContainer: app.descendants(matching: .any)[AXID.activityTrainingVolumeDetailScreen].firstMatch
        )
    }

    private func scrollUntilHittable(
        _ element: XCUIElement,
        maxSwipes: Int,
        scrollContainer: XCUIElement? = nil
    ) -> Bool {
        for _ in 0..<maxSwipes where !(element.exists && element.isHittable) {
            if let scrollContainer, scrollContainer.exists {
                scrollContainer.swipeUp()
            } else {
                app.swipeUp()
            }
        }

        return element.exists && element.isHittable
    }

    private func assertDetailChartScrollsToPastData(category: String) {
        let detailScreen = waitForElement(AXID.metricDetailScreen(category), timeout: 15)
        XCTAssertTrue(detailScreen.exists, "\(category) detail should open from seeded navigation")

        let visibleRange = waitForElement(AXID.detailChartVisibleRange, timeout: 15)
        let chart = waitForElement(AXID.detailChartSurface, timeout: 15)
        let initialRange = visibleRange.label

        let updatedRange = performHorizontalChartDragUntilRangeChanges(chart, initialRange: initialRange)
        XCTAssertNotEqual(
            updatedRange,
            initialRange,
            "Horizontal drag on the \(category) chart should reveal an older visible range"
        )
    }

    private func visibleRangeValue(of element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    private func waitForLabelChange(
        of element: XCUIElement,
        from initialLabel: String,
        timeout: TimeInterval = 1.5
    ) -> String {
        let deadline = Date().addingTimeInterval(timeout)
        var latestLabel = element.label

        while Date() < deadline {
            latestLabel = element.label
            if latestLabel != initialLabel {
                return latestLabel
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        return latestLabel
    }

    private func performHorizontalChartDragUntilRangeChanges(
        _ chart: XCUIElement,
        initialRange: String,
        attempts: [(startDX: CGFloat, endDX: CGFloat, duration: TimeInterval)] = [
            (0.88, 0.12, 0.05),
            (0.12, 0.88, 0.05),
            (0.92, 0.08, 0.05),
            (0.08, 0.92, 0.05),
            (0.84, 0.16, 0.05),
            (0.16, 0.84, 0.05),
        ],
        timeoutPerAttempt: TimeInterval = 1.5
    ) -> String {
        for attempt in attempts {
            let start = chart.coordinate(withNormalizedOffset: CGVector(dx: attempt.startDX, dy: 0.55))
            let end = chart.coordinate(withNormalizedOffset: CGVector(dx: attempt.endDX, dy: 0.55))
            start.press(forDuration: attempt.duration, thenDragTo: end)

            let updatedRange = waitForVisibleRangeChange(
                of: chart,
                from: initialRange,
                timeout: timeoutPerAttempt
            )
            if updatedRange != initialRange {
                return updatedRange
            }
        }

        return visibleRangeValue(of: chart)
    }

    private func waitForVisibleRangeChange(
        of element: XCUIElement,
        from initialRange: String,
        timeout: TimeInterval = 1.5
    ) -> String {
        let deadline = Date().addingTimeInterval(timeout)
        var latestRange = visibleRangeValue(of: element)

        while Date() < deadline {
            latestRange = visibleRangeValue(of: element)
            if latestRange != initialRange {
                return latestRange
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        return latestRange
    }

    private func assertChartVisibleRangeChanges(
        _ chart: XCUIElement,
        failureMessage: String
    ) {
        let initialRange = visibleRangeValue(of: chart)
        let updatedRange = performHorizontalChartDragUntilRangeChanges(chart, initialRange: initialRange)

        XCTAssertNotEqual(
            updatedRange,
            initialRange,
            failureMessage
        )
    }

    private func performLongPressUntilProbeChanges(
        chart: XCUIElement,
        selectionProbe: XCUIElement,
        attempts: [(startDX: CGFloat, endDX: CGFloat)] = [
            (0.45, 0.58),
            (0.48, 0.54),
            (0.40, 0.52),
        ],
        duration: TimeInterval = 0.45
    ) -> String {
        for attempt in attempts {
            let start = chart.coordinate(withNormalizedOffset: CGVector(dx: attempt.startDX, dy: 0.55))
            let end = chart.coordinate(withNormalizedOffset: CGVector(dx: attempt.endDX, dy: 0.55))
            start.press(forDuration: duration, thenDragTo: end)

            let probeLabel = waitForLabelChange(of: selectionProbe, from: "none")
            if probeLabel != "none" {
                return probeLabel
            }
        }

        return selectionProbe.label
    }
}
