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
        XCTAssertTrue(ring.waitForExistence(timeout: 10))
        XCTAssertTrue(ring.label.contains("100"), "Opt-in fixture should preserve the actual 100-point hero")
        XCTAssertTrue(app.staticTexts["condition-detail-hero-status"].firstMatch.exists)
        VisualAudit.capture("Condition detail top hero")

        for (metric, unit) in [("hrv", "ms"), ("rhr", "bpm")] {
            let id = "condition-contribution-\(metric)"
            XCTAssertTrue(app.scrollToElementIfNeeded(id, maxSwipes: 8), "\(id) should be reachable")
            XCTAssertTrue(app.descendants(matching: .any)[id].firstMatch.exists)
            let value = app.staticTexts["condition-contribution-value-\(metric)"].firstMatch
            let impact = app.staticTexts["condition-contribution-impact-\(metric)"].firstMatch
            XCTAssertTrue(value.exists && value.label.contains(unit)
                          && value.label.rangeOfCharacter(from: .decimalDigits) != nil,
                          "\(metric) should show a numeric \(unit) measurement")
            XCTAssertTrue(impact.exists, "\(metric) should expose its contribution impact")
            XCTAssertEqual(impact.label, "Impact unavailable",
                           "The opt-in score fixture has no contributions, so impact must not be inferred")
            VisualAudit.capture("Condition \(id) measurement and impact")
        }

        XCTAssertTrue(app.scrollToElementIfNeeded("condition-trend-card", maxSwipes: 8))
        XCTAssertTrue(app.descendants(matching: .any)["condition-trend-card"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["detail-chart-surface"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["score-detail-chart-visible-range"].firstMatch.exists)
        XCTAssertTrue(app.buttons["score-chart-trend-toggle"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["condition-visible-summary"].firstMatch.exists)
        for id in ["condition-summary-average", "condition-summary-min", "condition-summary-max"] {
            XCTAssertTrue(app.staticTexts[id].firstMatch.exists, "Visible summary should expose \(id)")
        }
        VisualAudit.capture("Condition unified trend and visible summary")
        XCTAssertTrue(screen.exists)
    }

    func testPeriodWindowAndTrendControlsUpdateVisibleReadback() {
        openConditionDetail()
        let picker = app.segmentedControls["condition-period-picker"].firstMatch
        XCTAssertTrue(app.scrollToElementIfNeeded("condition-period-picker", maxSwipes: 8))
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        XCTAssertEqual(picker.buttons.count, 5, "Condition should offer D, W, M, 6M, and Y")
        let range = app.staticTexts["score-detail-chart-visible-range"].firstMatch
        XCTAssertTrue(range.waitForExistence(timeout: 10))
        for period in ["D", "W", "M", "6M", "Y"] {
            let option = picker.buttons[period].firstMatch
            XCTAssertTrue(option.exists, "Missing \(period) period")
            let previousRange = range.label
            option.tap()
            XCTAssertTrue(waitForPeriod(option, range: range, replacing: previousRange),
                          "Selecting \(period) should update the selected segment and visible range")
        }

        let week = picker.buttons["W"].firstMatch
        let yearRange = range.label
        week.tap()
        XCTAssertTrue(waitForPeriod(week, range: range, replacing: yearRange),
                      "Week should be restored before moving its visible window")
        let summary = app.descendants(matching: .any)["condition-visible-summary"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        let initialRange = range.label
        let initialSummary = summaryText(summary)
        XCTAssertFalse(initialSummary.isEmpty, "Week should expose a visible-window summary")
        VisualAudit.capture("Condition week window and summary")

        let previous = app.buttons["condition-period-previous"].firstMatch
        let next = app.buttons["condition-period-next"].firstMatch
        XCTAssertTrue(previous.waitForExistence(timeout: 10))
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        previous.tap()
        XCTAssertNotEqual(waitForLabelChange(range, from: initialRange), initialRange,
                          "Previous should move the visible window")
        XCTAssertNotEqual(summaryText(summary), initialSummary,
                          "Visible summary should follow the moved window")
        VisualAudit.capture("Condition previous week and recalculated summary")
        let previousRange = range.label
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
        trend.tap()
        XCTAssertNotEqual(trend.value as? String, initialTrend, "Trend control should change state")
        VisualAudit.capture("Condition trend toggled")
    }

    func testPeriodControlsKeep44PointTargetsAndAcceptEdgeTaps() {
        openConditionDetail()
        XCTAssertTrue(app.scrollToElementIfNeeded("condition-period-previous", maxSwipes: 18))
        let previous = app.buttons["condition-period-previous"].firstMatch
        let next = app.buttons["condition-period-next"].firstMatch
        let trend = app.buttons["score-chart-trend-toggle"].firstMatch
        for button in [previous, next, trend] {
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, "The full control height must be tappable")
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, "The full control width must be tappable")
        }
        let range = app.staticTexts["score-detail-chart-visible-range"].firstMatch
        let initial = range.label
        previous.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        XCTAssertNotEqual(waitForLabelChange(range, from: initial), initial)
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in range.label == initial }, object: range)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed)
        trend.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in trend.value as? String == "On" }, object: trend)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        VisualAudit.capture("Condition full period control hit targets")
    }

    func testSingleNativeExplainerExpandsCalculationAndOriginalItems() {
        openConditionDetail()
        XCTAssertTrue(app.scrollToElementIfNeeded("condition-score-explainer", maxSwipes: 18))
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
        XCTAssertTrue(score.waitForExistence(timeout: 10))
        XCTAssertTrue(score.label.contains("100"), "The accessible score label should retain its numeric value")
        VisualAudit.capture("Condition maximum AX hero")

        for id in ["condition-contribution-hrv", "condition-contribution-rhr", "condition-time-of-day", "condition-trend-card", "condition-score-explainer"] {
            XCTAssertTrue(app.scrollToElementIfNeeded(id, maxSwipes: 18), "\(id) should remain reachable at maximum AX")
            XCTAssertTrue(app.descendants(matching: .any)[id].firstMatch.exists,
                          "\(id) should remain in the accessibility tree")
            VisualAudit.capture("Condition maximum AX \(id) viewport")
        }
        tapExplainerHeader()
        XCTAssertTrue(app.descendants(matching: .any)["condition-calculation-content"].firstMatch.waitForExistence(timeout: 10))
        VisualAudit.capture("Condition maximum AX expanded explanation")
    }

    private func tapExplainerHeader() {
        let title = app.staticTexts["How the Score Works"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Native disclosure title should exist")
        for _ in 0..<18 {
            if title.isHittable {
                title.tap() // Tap the 44pt header text frame, never the expanded group's full frame.
                return
            }
            if title.frame.midY < detailScreen.frame.minY {
                detailScreen.swipeDown(velocity: .slow)
            } else {
                detailScreen.swipeUp(velocity: .slow)
            }
        }
        XCTFail("Native disclosure title should be reachable")
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
