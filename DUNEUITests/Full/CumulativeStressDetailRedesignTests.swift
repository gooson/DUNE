@preconcurrency import XCTest

/// T05 contracts reached through Today's real cumulative stress card.
@MainActor
final class CumulativeStressDetailRedesignTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "today" }
    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-morningBriefingDisabled", "YES",
         "--ui-visual-stress-fixture", "--ui-visual-cumulative-stress-fixture"]
    }

    func testHeroFactorsAndUnifiedTrendAreVisible() {
        openStressDetail()
        let ring = app.descendants(matching: .any)["stress-detail-hero-ring"].firstMatch
        let status = app.staticTexts["stress-detail-hero-status"].firstMatch
        XCTAssertTrue(revealWhole(ring), "The complete 42-point ring must reach the viewport")
        XCTAssertTrue(ring.label.contains("42"), "The opt-in Today fixture supplies the current score")
        XCTAssertTrue(revealWhole(status))
        VisualAudit.capture("Stress detail hero and status")

        for item in factors {
            let icon = app.images["stress-contribution-icon-\(item.id)"].firstMatch
            let rawScore = app.staticTexts["stress-contribution-score-\(item.id)"].firstMatch
            let progress = app.descendants(matching: .any)["stress-contribution-progress-\(item.id)"].firstMatch
            let appliedWeight = app.staticTexts["stress-contribution-weight-\(item.id)"].firstMatch
            XCTAssertTrue(revealWhole(icon), "\(item.id) original icon must be visible")
            XCTAssertTrue(revealWhole(rawScore), "\(item.id) raw score must be visible")
            XCTAssertEqual(rawScore.label, item.rawScore)
            XCTAssertTrue(revealWhole(progress), "\(item.id) progress track must be visible")
            XCTAssertTrue((progress.value as? String)?.contains(item.rawScore) == true,
                          "The progress accessibility value must report the actual raw score")
            XCTAssertTrue(revealWhole(appliedWeight), "\(item.id) applied weight must be visible")
            XCTAssertTrue(appliedWeight.label.contains(item.weight),
                          "Applied weight must agree with the fixture's available contributions")
            VisualAudit.capture("Stress \(item.id) raw score, progress and applied weight")
        }

        let trendCard = app.descendants(matching: .any)["stress-trend-card"].firstMatch
        let range = app.staticTexts["score-detail-chart-visible-range"].firstMatch
        let average = app.staticTexts["stress-summary-average"].firstMatch
        let minimum = app.staticTexts["stress-summary-min"].firstMatch
        let maximum = app.staticTexts["stress-summary-max"].firstMatch
        XCTAssertTrue(trendCard.waitForExistence(timeout: 10))
        XCTAssertTrue(revealWhole(range))
        XCTAssertTrue(revealWhole(average), "Seeded stress history must yield a visible average")
        XCTAssertTrue(revealWhole(minimum))
        XCTAssertTrue(revealWhole(maximum))
        XCTAssertTrue(app.descendants(matching: .any)["stress-visible-summary"].firstMatch.exists)
        XCTAssertTrue(waitForVisibleHistory(), "The chart must render recorded points, not invented zeros")
        VisualAudit.capture("Stress unified trend and visible summary")
    }

    func testFivePeriodsPagingSummaryAndTrendReadback() {
        openStressDetail()
        let picker = app.segmentedControls["stress-period-picker"].firstMatch
        XCTAssertTrue(revealWhole(picker, requireHittable: true))
        XCTAssertEqual(picker.buttons.count, 5)
        let range = app.staticTexts["score-detail-chart-visible-range"].firstMatch
        XCTAssertTrue(range.waitForExistence(timeout: 10))

        for period in ["D", "W", "M", "6M", "Y"] {
            let option = picker.buttons[period].firstMatch
            XCTAssertTrue(revealWhole(option, requireHittable: true), "\(period) must be tappable")
            let prior = range.label
            let wasSelected = option.isSelected
            option.tap()
            if !wasSelected {
                XCTAssertTrue(waitForPeriod(option, range: range, replacing: prior),
                              "\(period) must select a new visible date range")
            } else {
                XCTAssertTrue(option.isSelected)
            }
            XCTAssertTrue(waitForVisibleHistory(), "\(period) must contain real seeded history")
        }
        VisualAudit.capture("Stress five selectable periods")

        let week = picker.buttons["W"].firstMatch
        let yearRange = range.label
        XCTAssertTrue(revealWhole(week, requireHittable: true))
        week.tap()
        XCTAssertTrue(waitForPeriod(week, range: range, replacing: yearRange))
        let summary = app.descendants(matching: .any)["stress-visible-summary"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        let initialRange = range.label
        let initialSummary = summaryText(summary)
        XCTAssertFalse(initialSummary.isEmpty)
        XCTAssertTrue(revealWhole(app.staticTexts["stress-summary-average"].firstMatch))
        VisualAudit.capture("Stress current week summary")

        let previous = app.buttons["stress-period-previous"].firstMatch
        let next = app.buttons["stress-period-next"].firstMatch
        XCTAssertTrue(revealWhole(previous, requireHittable: true))
        previous.tap()
        XCTAssertNotEqual(waitForLabelChange(range, from: initialRange), initialRange)
        XCTAssertTrue(waitForVisibleHistory(), "Previous week must contain recorded data")
        XCTAssertNotEqual(waitForSummaryChange(summary, from: initialSummary), initialSummary,
                          "Week paging must recalculate summary from the new visible interval")
        XCTAssertTrue(revealWhole(app.staticTexts["stress-summary-average"].firstMatch))
        VisualAudit.capture("Stress previous week recalculated summary")

        let previousRange = range.label
        XCTAssertTrue(revealWhole(next, requireHittable: true))
        next.tap()
        XCTAssertEqual(waitForLabelChange(range, from: previousRange), initialRange)
        let trend = app.buttons["score-chart-trend-toggle"].firstMatch
        XCTAssertTrue(revealWhole(trend, requireHittable: true))
        guard let initialTrend = trend.value as? String else {
            XCTFail("Trend toggle must expose its On or Off accessibility value")
            return
        }
        XCTAssertTrue(["On", "Off"].contains(initialTrend))
        trend.tap()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in trend.value as? String != initialTrend },
            object: trend
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        VisualAudit.capture("Stress restored week and trend toggled")
    }

    func testSingleDisclosureRetainsAllOriginalExplanationsAndActualFactors() {
        openStressDetail()
        let title = app.staticTexts["stress-score-explainer"].firstMatch
        XCTAssertTrue(revealWhole(title, requireHittable: true))
        XCTAssertEqual(title.label, "How Stress Score Works")
        XCTAssertFalse(app.staticTexts["What is Cumulative Stress?"].firstMatch.exists)
        title.tap()
        let headings = [
            "What is Cumulative Stress?", "HRV Variability (40%)",
            "Sleep Consistency (35%)", "Activity Load (25%)"
        ]
        for heading in headings {
            XCTAssertTrue(app.staticTexts[heading].firstMatch.waitForExistence(timeout: 10),
                          "Original explanation must survive the single disclosure: \(heading)")
        }
        for phrase in [
            "A 30-day composite indicator",
            "Measures day-to-day fluctuation",
            "Evaluates regularity",
            "Compares recent training volume"
        ] {
            XCTAssertTrue(app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", phrase)
            ).firstMatch.exists, "Original explanation body must remain: \(phrase)")
        }
        for item in factors {
            let actual = app.staticTexts["stress-explainer-score-\(item.id)"].firstMatch
            XCTAssertTrue(actual.exists, "Expanded calculation must include \(item.id)")
            XCTAssertTrue(actual.label.contains(item.rawScore),
                          "Expanded calculation must retain the current raw score")
        }
        VisualAudit.capture("Stress single expanded calculation and original explanations")

        XCTAssertTrue(revealWhole(title, requireHittable: true))
        title.tap()
        XCTAssertTrue(app.staticTexts["What is Cumulative Stress?"].firstMatch
            .waitForNonExistence(timeout: 5), "A second nested disclosure must not remain open")
    }

    func testMaximumAccessibilitySizeKeepsHeroFactorsTrendAndDisclosureUsable() {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        openStressDetail(relaunch: false)
        let score = app.staticTexts["stress-detail-score"].firstMatch
        XCTAssertTrue(revealWhole(score), "Maximum AX hero score must fit")
        XCTAssertTrue(score.label.contains("42"))
        VisualAudit.capture("Stress maximum AX hero")

        for item in factors {
            let icon = app.images["stress-contribution-icon-\(item.id)"].firstMatch
            let raw = app.staticTexts["stress-contribution-score-\(item.id)"].firstMatch
            let weight = app.staticTexts["stress-contribution-weight-\(item.id)"].firstMatch
            XCTAssertTrue(revealWhole(icon))
            XCTAssertTrue(revealWhole(raw))
            XCTAssertTrue(revealWhole(weight))
            XCTAssertEqual(raw.label, item.rawScore)
            XCTAssertTrue(weight.label.contains(item.weight))
            XCTAssertFalse(icon.frame.intersects(weight.frame), "Icon and weight must not overlap")
            VisualAudit.capture("Stress maximum AX \(item.id) factor viewport")
        }

        let range = app.staticTexts["score-detail-chart-visible-range"].firstMatch
        let previous = app.buttons["stress-period-previous"].firstMatch
        let next = app.buttons["stress-period-next"].firstMatch
        XCTAssertTrue(revealWhole(range))
        XCTAssertTrue(revealWhole(previous, requireHittable: true))
        XCTAssertTrue(revealWhole(next, requireHittable: true))
        let plot = app.otherElements["chart-selection-probe"].firstMatch
        XCTAssertTrue(plot.waitForExistence(timeout: 10), "Recorded plot must expose its footprint")
        let controlsBottom = max(range.frame.maxY, previous.frame.maxY, next.frame.maxY)
        XCTAssertGreaterThanOrEqual(plot.frame.minY + 0.000_001, controlsBottom,
                                    "Scaled chart must not overlap the period controls")
        XCTAssertTrue(revealWhole(app.staticTexts["stress-summary-average"].firstMatch))
        VisualAudit.capture("Stress maximum AX chart and visible summary")

        let title = app.staticTexts["stress-score-explainer"].firstMatch
        XCTAssertTrue(revealWhole(title, requireHittable: true))
        title.tap()
        XCTAssertTrue(app.staticTexts["What is Cumulative Stress?"].firstMatch
            .waitForExistence(timeout: 10))
        VisualAudit.capture("Stress maximum AX expanded explanation")
    }

    func testDarkAppearanceKeepsKeyContentReachable() {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["-AppleInterfaceStyle", "Dark"]
        launchApp(with: configuration)
        openStressDetail(relaunch: false)
        let ring = app.descendants(matching: .any)["stress-detail-hero-ring"].firstMatch
        XCTAssertTrue(revealWhole(ring))
        XCTAssertTrue(ring.label.contains("42"))
        XCTAssertTrue(revealWhole(app.staticTexts["stress-contribution-score-hrvVariability"].firstMatch))
        XCTAssertTrue(revealWhole(app.staticTexts["score-detail-chart-visible-range"].firstMatch))
        XCTAssertTrue(revealWhole(app.staticTexts["stress-summary-average"].firstMatch))
        VisualAudit.capture("Stress dark hero, factors and trend")
    }

    private var factors: [(id: String, rawScore: String, weight: String)] {
        [
            ("hrvVariability", "40", "50%"),
            ("sleepConsistency", "46", "30%"),
            ("activityLoad", "38", "20%")
        ]
    }

    private var detailScreen: XCUIElement {
        app.scrollViews["cumulative-stress-detail-screen"].firstMatch
    }

    private func openStressDetail(relaunch: Bool = true) {
        if relaunch { launchApp() }
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("dashboard-stress-details", maxSwipes: 12))
        app.descendants(matching: .any)["dashboard-stress-details"].firstMatch.auditTap()
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10))
    }

    /// Reveal against the actual scroll/window intersection, never AX existence alone.
    private func revealWhole(_ target: XCUIElement, requireHittable: Bool = false) -> Bool {
        guard detailScreen.waitForExistence(timeout: 10),
              target.waitForExistence(timeout: 10) else { return false }
        let scroll = detailScreen
        for _ in 0..<32 {
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 4)
            if viewport.contains(target.frame) && (!requireHittable || target.isHittable) { return true }
            let moveUp = target.frame.midY > viewport.midY
            let start: CGFloat = moveUp ? 0.75 : 0.25
            let end: CGFloat = moveUp ? 0.25 : 0.75
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: start))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.05, dy: end)
                ), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 4)
        return viewport.contains(target.frame) && (!requireHittable || target.isHittable)
    }

    private func waitForPeriod(_ option: XCUIElement, range: XCUIElement, replacing prior: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in option.isSelected && range.label != prior },
            object: option
        )
        return XCTWaiter.wait(for: [expectation], timeout: 8) == .completed
    }

    private func waitForVisibleHistory() -> Bool {
        let probe = app.descendants(matching: .any)["stress-history-probe"].firstMatch
        guard probe.waitForExistence(timeout: 10) else { return false }
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let label = probe.label
                guard label.hasPrefix("visible-points:"),
                      let count = Int(label.dropFirst("visible-points:".count)) else { return false }
                return count > 0
            },
            object: probe
        )
        return XCTWaiter.wait(for: [expectation], timeout: 10) == .completed
    }

    private func summaryText(_ summary: XCUIElement) -> String {
        let children = summary.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
        return children.isEmpty ? summary.label : children
    }

    private func waitForSummaryChange(_ summary: XCUIElement, from prior: String) -> String {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let children = summary.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
                return (children.isEmpty ? summary.label : children) != prior
            },
            object: summary
        )
        _ = XCTWaiter.wait(for: [expectation], timeout: 8)
        return summaryText(summary)
    }

    private func waitForLabelChange(_ element: XCUIElement, from prior: String) -> String {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in element.label != prior },
            object: element
        )
        _ = XCTWaiter.wait(for: [expectation], timeout: 8)
        return element.label
    }
}
