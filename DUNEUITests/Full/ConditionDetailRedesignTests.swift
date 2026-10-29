@preconcurrency import XCTest

/// T04 Condition detail contracts from the Today hero. Chart drag lifecycle has its own regression suite.
@MainActor
final class ConditionDetailRedesignTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "today" }
    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-morningBriefingDisabled", "YES",
         "--ui-visual-condition-components-fixture"]
    }

    func testHeroContributionsAndUnifiedTrendAreReachable() {
        openConditionDetail()
        let screen = detailScreen
        let ring = app.descendants(matching: .any)["condition-detail-hero-ring"].firstMatch
        XCTAssertTrue(revealWhole(ring), "The complete hero ring should be in the captured viewport")
        XCTAssertTrue(ring.label.contains("100"), "Opt-in fixture should preserve the actual 100-point hero")
        XCTAssertTrue(revealWhole(app.staticTexts["condition-detail-hero-status"].firstMatch))
        VisualAudit.capture("Condition detail top hero")

        for (metric, unit) in [("hrv", "ms"), ("rhr", "bpm")] {
            let id = "condition-contribution-\(metric)"
            XCTAssertTrue(app.descendants(matching: .any)[id].firstMatch.exists)
            let value = app.staticTexts["condition-contribution-value-\(metric)"].firstMatch
            let impact = app.staticTexts["condition-contribution-impact-\(metric)"].firstMatch
            XCTAssertTrue(revealWhole(value), "\(id) measurement should be fully visible")
            XCTAssertTrue(revealWhole(impact), "\(id) impact should be fully visible")
            XCTAssertTrue(value.exists && value.label.contains(unit)
                          && value.label.rangeOfCharacter(from: .decimalDigits) != nil,
                          "\(metric) should show a numeric \(unit) measurement")
            XCTAssertTrue(impact.exists, "\(metric) should expose its contribution impact")
            XCTAssertEqual(impact.label, "Impact unavailable",
                           "The opt-in score fixture has no contributions, so impact must not be inferred")
            VisualAudit.capture("Condition \(id) measurement and impact")
        }

        XCTAssertTrue(app.descendants(matching: .any)["condition-trend-card"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["detail-chart-surface"].firstMatch.waitForExistence(timeout: 15))
        let visibleRange = app.staticTexts["score-detail-chart-visible-range"].firstMatch
        let trend = app.buttons["score-chart-trend-toggle"].firstMatch
        XCTAssertTrue(revealWhole(visibleRange), "Trend header should be fully visible")
        XCTAssertTrue(revealWhole(trend, requireHittable: true), "Trend toggle should be visible and usable")
        VisualAudit.capture("Condition unified trend header and controls")
        XCTAssertTrue(app.descendants(matching: .any)["condition-visible-summary"].firstMatch.exists)
        for id in ["condition-summary-average", "condition-summary-min", "condition-summary-max"] {
            XCTAssertTrue(revealWhole(app.staticTexts[id].firstMatch), "Visible summary row \(id) should fit")
        }
        VisualAudit.capture("Condition visible summary rows")
        XCTAssertTrue(screen.exists)
    }

    func testPeriodWindowAndTrendControlsUpdateVisibleReadback() {
        openConditionDetail()
        let picker = app.segmentedControls["condition-period-picker"].firstMatch
        XCTAssertTrue(revealWhole(picker, requireHittable: true), "Period picker should fit in the viewport")
        XCTAssertEqual(picker.buttons.count, 5, "Condition should offer D, W, M, 6M, and Y")
        let range = app.staticTexts["score-detail-chart-visible-range"].firstMatch
        XCTAssertTrue(range.waitForExistence(timeout: 10))
        for period in ["D", "W", "M", "6M", "Y"] {
            let option = picker.buttons[period].firstMatch
            XCTAssertTrue(option.exists, "Missing \(period) period")
            let previousRange = range.label
            XCTAssertTrue(revealWhole(option, requireHittable: true), "\(period) should be tappable")
            option.tap()
            XCTAssertTrue(waitForPeriod(option, range: range, replacing: previousRange),
                          "Selecting \(period) should update the selected segment and visible range")
        }

        let week = picker.buttons["W"].firstMatch
        let yearRange = range.label
        XCTAssertTrue(revealWhole(week, requireHittable: true))
        week.tap()
        XCTAssertTrue(waitForPeriod(week, range: range, replacing: yearRange),
                      "Week should be restored before moving its visible window")
        let summary = app.descendants(matching: .any)["condition-visible-summary"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        let initialRange = range.label
        let initialSummary = summaryText(summary)
        XCTAssertFalse(initialSummary.isEmpty, "Week should expose a visible-window summary")
        XCTAssertTrue(revealWhole(app.staticTexts["condition-summary-average"].firstMatch))
        VisualAudit.capture("Condition week window summary")

        let previous = app.buttons["condition-period-previous"].firstMatch
        let next = app.buttons["condition-period-next"].firstMatch
        XCTAssertTrue(previous.waitForExistence(timeout: 10))
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        XCTAssertTrue(revealWhole(previous, requireHittable: true))
        previous.tap()
        XCTAssertNotEqual(waitForLabelChange(range, from: initialRange), initialRange,
                          "Previous should move the visible window")
        XCTAssertNotEqual(summaryText(summary), initialSummary,
                          "Visible summary should follow the moved window")
        XCTAssertTrue(revealWhole(app.staticTexts["condition-summary-average"].firstMatch))
        VisualAudit.capture("Condition previous week recalculated summary")
        let previousRange = range.label
        XCTAssertTrue(revealWhole(next, requireHittable: true))
        next.tap()
        XCTAssertEqual(waitForLabelChange(range, from: previousRange), initialRange,
                       "Next should restore the current week")

        let trend = app.buttons["score-chart-trend-toggle"].firstMatch
        XCTAssertTrue(trend.waitForExistence(timeout: 10))
        guard let initialTrend = trend.value as? String else {
            XCTFail("Trend should expose On/Off accessibility state")
            return
        }
        XCTAssertTrue(["On", "Off"].contains(initialTrend), "Trend should expose On/Off accessibility state")
        XCTAssertTrue(revealWhole(trend, requireHittable: true))
        trend.tap()
        XCTAssertNotEqual(trend.value as? String, initialTrend, "Trend control should change state")
        VisualAudit.capture("Condition trend toggled")
    }

    func testPeriodControlsKeep44PointTargetsAndAcceptEdgeTaps() {
        openConditionDetail()
        XCTAssertTrue(revealWhole(app.buttons["condition-period-previous"].firstMatch, requireHittable: true))
        let previous = app.buttons["condition-period-previous"].firstMatch
        let next = app.buttons["condition-period-next"].firstMatch
        let trend = app.buttons["score-chart-trend-toggle"].firstMatch
        let coordinateRoundingTolerance: CGFloat = 0.000_001
        for button in [previous, next, trend] {
            XCTAssertGreaterThanOrEqual(button.frame.height + coordinateRoundingTolerance, 44,
                                        "The full control height must be tappable")
            XCTAssertGreaterThanOrEqual(button.frame.width + coordinateRoundingTolerance, 44,
                                        "The full control width must be tappable")
        }
        let range = app.staticTexts["score-detail-chart-visible-range"].firstMatch
        let initial = range.label
        XCTAssertTrue(revealWhole(previous, requireHittable: true), "Previous edge needs the full 44pt frame")
        previous.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        XCTAssertNotEqual(waitForLabelChange(range, from: initial), initial)
        XCTAssertTrue(revealWhole(next, requireHittable: true), "Next edge needs the full 44pt frame")
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in range.label == initial }, object: range)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed)
        XCTAssertTrue(revealWhole(trend, requireHittable: true), "Trend edge needs the full 44pt frame")
        trend.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in trend.value as? String == "On" }, object: trend)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        VisualAudit.capture("Condition full period control hit targets")
    }

    func testSingleNativeExplainerExpandsCalculationAndOriginalItems() {
        openConditionDetail()
        XCTAssertTrue(revealWhole(app.staticTexts["How the Score Works"].firstMatch, requireHittable: true))
        let disclosure = app.descendants(matching: .any)["condition-score-explainer"].firstMatch
        let calculation = app.descendants(matching: .any)["condition-calculation-content"].firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["How the Score Works"].firstMatch.exists,
                      "The single explainer should keep its existing title")
        XCTAssertFalse(calculation.exists, "Calculation starts collapsed")
        tapExplainerHeader()
        XCTAssertTrue(calculation.waitForExistence(timeout: 10))
        for id in ["condition-explanation-hrv", "condition-explanation-baseline", "condition-explanation-score", "condition-explanation-rhr"] {
            XCTAssertTrue(app.descendants(matching: .any)[id].firstMatch.exists,
                          "Original explanation \(id) should remain")
        }
        for row in ["Today HRV", "Baseline HRV", "Z-Score", "StdDev (ln)", "Raw Score"] {
            XCTAssertTrue(app.staticTexts[row].firstMatch.exists, "Calculation row \(row) should remain")
        }
        VisualAudit.capture("Condition expanded calculation and explanations")
        tapExplainerHeader()
        XCTAssertTrue(calculation.waitForNonExistence(timeout: 5), "Disclosure should collapse its calculation")
    }

    func testMaximumAccessibilitySizeKeepsHeroTrendAndExplainerUsable() {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchApp(with: configuration)
        openConditionDetail(relaunch: false)
        let score = app.staticTexts["condition-detail-score"].firstMatch
        XCTAssertTrue(revealWhole(score), "The AX hero score should fit in the captured viewport")
        XCTAssertTrue(score.label.contains("100"), "The accessible score label should retain its numeric value")
        VisualAudit.capture("Condition maximum AX hero")

        for metric in ["hrv", "rhr"] {
            let id = "condition-contribution-\(metric)"
            XCTAssertTrue(app.descendants(matching: .any)[id].firstMatch.exists)
            XCTAssertTrue(revealWhole(app.staticTexts["condition-contribution-value-\(metric)"].firstMatch))
            VisualAudit.capture("Condition maximum AX \(id) value viewport")
        }
        let timeOfDay = app.descendants(matching: .any)["condition-time-of-day"].firstMatch
        XCTAssertTrue(revealCenter(timeOfDay), "Time-of-day card should have a visible viewport")
        VisualAudit.capture("Condition maximum AX time-of-day viewport")
        XCTAssertTrue(app.descendants(matching: .any)["condition-trend-card"].firstMatch.exists)
        XCTAssertTrue(revealWhole(app.staticTexts["score-detail-chart-visible-range"].firstMatch))
        VisualAudit.capture("Condition maximum AX trend header viewport")
        XCTAssertTrue(revealWhole(app.staticTexts["condition-summary-average"].firstMatch))
        VisualAudit.capture("Condition maximum AX visible summary viewport")
        XCTAssertTrue(revealWhole(app.staticTexts["How the Score Works"].firstMatch, requireHittable: true))
        VisualAudit.capture("Condition maximum AX explainer header viewport")
        tapExplainerHeader()
        XCTAssertTrue(app.descendants(matching: .any)["condition-calculation-content"].firstMatch.waitForExistence(timeout: 10))
        VisualAudit.capture("Condition maximum AX expanded explanation")
    }

    private func tapExplainerHeader() {
        let title = app.staticTexts["How the Score Works"].firstMatch
        XCTAssertTrue(revealWhole(title, requireHittable: true), "Native disclosure title should be reachable")
        title.tap() // Tap the header text frame, never the expanded group's full frame.
    }

    private func revealWhole(_ target: XCUIElement, requireHittable: Bool = false) -> Bool {
        reveal(target, requireWholeFrame: true, requireHittable: requireHittable)
    }

    private func revealCenter(_ target: XCUIElement) -> Bool {
        reveal(target, requireWholeFrame: false, requireHittable: false)
    }

    /// Use the outer scroll gutter so a nested chart cannot consume the vertical drag.
    private func reveal(_ target: XCUIElement, requireWholeFrame: Bool, requireHittable: Bool) -> Bool {
        guard detailScreen.waitForExistence(timeout: 10), target.waitForExistence(timeout: 10) else { return false }
        let scroll = detailScreen
        for _ in 0..<32 {
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 4)
            let frame = target.frame
            let visible = requireWholeFrame ? viewport.contains(frame) : viewport.contains(
                CGPoint(x: frame.midX, y: frame.midY)
            )
            if visible && (!requireHittable || target.isHittable) { return true }
            let targetY = frame.midY
            let moveUp = targetY > viewport.midY
            let startY: CGFloat = moveUp ? 0.75 : 0.25
            let endY: CGFloat = moveUp ? 0.25 : 0.75
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: startY))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.05, dy: endY)
                ), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 4)
        let frame = target.frame
        let visible = requireWholeFrame ? viewport.contains(frame) : viewport.contains(
            CGPoint(x: frame.midX, y: frame.midY)
        )
        return visible && (!requireHittable || target.isHittable)
    }

    private func waitForPeriod(_ option: XCUIElement, range: XCUIElement, replacing prior: String) -> Bool {
        let predicate = NSPredicate { _, _ in option.isSelected && range.label != prior }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: option)
        return XCTWaiter.wait(for: [expectation], timeout: 8) == .completed
    }

    private var detailScreen: XCUIElement {
        app.scrollViews["condition-score-detail-screen"].firstMatch
    }

    private func openConditionDetail(relaunch: Bool = true) {
        if relaunch { launchApp() }
        let entry = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.dashboardHeroCondition, maxSwipes: 8))
        entry.auditTap()
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10))
    }

    private func summaryText(_ summary: XCUIElement) -> String {
        let children = summary.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
        return children.isEmpty ? summary.label : children
    }

    private func waitForLabelChange(_ element: XCUIElement, from prior: String) -> String {
        let predicate = NSPredicate { _, _ in element.label != prior }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        _ = XCTWaiter.wait(for: [expectation], timeout: 5)
        return element.label
    }
}
