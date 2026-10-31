@preconcurrency import XCTest

/// Neutral normal-text capture that runs on both the original and redesigned A02 view.
@MainActor
final class TrainingReadinessDetailRedesignTests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "--ui-test-style", "light", "--ui-disable-animations",
            "-morningBriefingDisabled", "YES"
        ]
    }

    func testSeededReadinessNormalScreenAndCapture() {
        navigateToActivity()
        let readinessHero = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(readinessHero.waitForExistence(timeout: 15), "Seeded Activity readiness entry should exist")
        XCTAssertTrue(readinessHero.isHittable, "Activity readiness entry should be tappable")
        readinessHero.auditTap()

        let detail = app.scrollViews[AXID.activityTrainingReadinessDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "Training Readiness detail should open")
        let navigation = app.navigationBars["Training Readiness"].firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 5), "Original Training Readiness title should remain")

        // Capture the untouched top viewport before probing lower sections or scrolling.
        addScreenshotAttachment(named: "A02 seeded normal text detail top")
        VisualAudit.capture("A02 seeded normal text detail top")

        let periods = app.segmentedControls[AXID.trainingReadinessPeriodPicker].firstMatch
        XCTAssertTrue(periods.waitForExistence(timeout: 10), "The existing five-period control should remain")
        for label in ["D", "W", "M", "6M", "Y"] {
            XCTAssertTrue(periods.buttons[label].exists, "The original \(label) period should remain")
        }
        let composition = app.descendants(matching: .any)["score-composition-card"].firstMatch
        XCTAssertTrue(composition.waitForExistence(timeout: 10), "The original score composition should remain")
        for (title, weight) in [
            ("HRV Variability", "30%"),
            ("Sleep Quality", "25%"),
            ("Resting Heart Rate", "20%"),
            ("Recovery Status", "15%"),
            ("Trend Bonus", "10%")
        ] {
            let row = composition.descendants(matching: .staticText).matching(
                NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", title, weight)
            ).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5), "Original \(title) \(weight) contribution should remain")
        }

        let back = navigation.buttons.firstMatch
        XCTAssertTrue(back.exists && back.isHittable, "Native Back should be usable")
        back.auditTap()
        XCTAssertTrue(readinessHero.waitForExistence(timeout: 8), "Back should return to Activity")
        XCTAssertTrue(detail.waitForNonExistence(timeout: 5), "Detail should close after native Back")
    }

    func testActualScoreStatusAndFiveContributions() {
        navigateToActivity()
        let rootRing = app.descendants(matching: .any)["activity-hero-ring"].firstMatch
        XCTAssertTrue(rootRing.waitForExistence(timeout: 15), "Seeded Activity must expose its actual readiness score")
        let rootLabel = rootRing.label
        let parts = rootLabel.split(separator: ",", maxSplits: 1)
        guard parts.count == 2,
              let scoreValue = parts[0].split(separator: " ").last,
              let score = Int(scoreValue) else {
            XCTFail("Unrecognized Activity readiness score: \(rootLabel)")
            return
        }
        let status = String(parts[1]).trimmingCharacters(in: .whitespaces)
        XCTAssertTrue((0...100).contains(score))
        XCTAssertEqual(status, statusName(for: score), "Status must follow the model score band")

        openDetail()
        let detailRing = app.descendants(matching: .any)["training-readiness-detail-hero-ring"].firstMatch
        XCTAssertTrue(detailRing.waitForExistence(timeout: 10))
        XCTAssertEqual(detailRing.label, rootLabel, "Detail must show the same actual score and status as Activity")
        XCTAssertEqual(app.descendants(matching: .any)["training-readiness-detail-status"].firstMatch.label, status)
        let statusIcon = app.descendants(matching: .any)["training-readiness-detail-status-icon"].firstMatch
        XCTAssertTrue(statusIcon.exists)
        XCTAssertEqual(statusIcon.label, status, "The original status symbol must carry its model status")
        let date = app.descendants(matching: .any)["training-readiness-detail-evaluation-date"].firstMatch
        XCTAssertTrue(date.exists && !date.label.isEmpty, "Use the actual evaluation date")

        let composition = app.descendants(matching: .any)["score-composition-card"].firstMatch
        XCTAssertTrue(composition.waitForExistence(timeout: 10))
        for factor in factors {
            let heroRow = app.descendants(matching: .any)["training-readiness-detail-factor-\(factor.id)"].firstMatch
            let compositionRow = composition.descendants(matching: .staticText).matching(NSPredicate(
                format: "label CONTAINS %@ AND label CONTAINS %@", factor.title, factor.weight
            )).firstMatch
            XCTAssertTrue(heroRow.exists && compositionRow.exists, "Missing actual \(factor.title) contribution")
            XCTAssertTrue(heroRow.label.contains(factor.title) && heroRow.label.contains(factor.weight),
                          "The factor score and contribution weight must remain distinct")
            let heroScore = lastScore(in: heroRow.label)
            let originalScore = lastScore(in: compositionRow.label)
            XCTAssertNotNil(heroScore)
            XCTAssertEqual(heroScore, originalScore, "\(factor.title) must use the actual computed component score")
            if let heroScore { XCTAssertTrue((0...100).contains(heroScore)) }
        }
        addScreenshotAttachment(named: "A02 actual readiness score and five contributions")
    }

    func testFivePeriodsTrendAndSourceSubtrends() {
        openDetail()
        let trendCard = app.descendants(matching: .any)["training-readiness-detail-trend-card"].firstMatch
        XCTAssertTrue(trendCard.waitForExistence(timeout: 10))
        let periods = app.segmentedControls[AXID.trainingReadinessPeriodPicker].firstMatch
        let range = trendCard.staticTexts["score-detail-chart-visible-range"].firstMatch
        let toggle = trendCard.buttons["score-chart-trend-toggle"].firstMatch
        let scroll = detailScreen
        XCTAssertTrue(periods.waitForExistence(timeout: 10) && range.waitForExistence(timeout: 15))
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertTrue(chartArea
            .waitForExistence(timeout: 15), "Seeded Week must render its existing chart")
        XCTAssertTrue(trendCard.staticTexts["Period Summary"].firstMatch.waitForExistence(timeout: 15),
                      "Actual history summary must remain under the chart")
        XCTAssertTrue(trendStateProbe.waitForExistence(timeout: 10))
        let initialTrend = trendStateProbe.label
        XCTAssertTrue(revealWhole(toggle, in: scroll) && toggle.isHittable)
        toggle.auditTap()
        XCTAssertTrue(waitForLabelChange(trendStateProbe, from: initialTrend),
                      "Trend must compute visible history endpoints")
        XCTAssertTrue(trendStateProbe.label.hasPrefix("trend-endpoints:"))
        XCTAssertNotEqual(trendStateProbe.label, "trend-endpoints:none")

        for label in ["D", "W", "M", "6M", "Y"] {
            let option = periods.buttons[label].firstMatch
            XCTAssertTrue(option.exists && revealWhole(option, in: scroll) && option.isHittable,
                          "\(label) must be reachable")
            let previousRange = range.label
            option.auditTap()
            XCTAssertTrue(option.isSelected, "\(label) must select")
            XCTAssertTrue(waitForLabelChange(range, from: previousRange),
                          "\(label) must update the visible range")
            for id in [AXID.trainingReadinessSubscoreHRV,
                       AXID.trainingReadinessSubscoreRHR,
                       AXID.trainingReadinessSubscoreSleep] {
                let subtrend = app.descendants(matching: .any)[id].firstMatch
                if label == "D" {
                    XCTAssertFalse(subtrend.exists, "Day uses rolling snapshots without non-day source charts")
                } else {
                    XCTAssertTrue(subtrend.waitForExistence(timeout: 10), "\(label) must keep source chart \(id)")
                }
            }
        }
        addScreenshotAttachment(named: "A02 five periods and actual trend")
    }

    func testSeededWeekChartPointSelection() {
        openDetail()
        let scroll = detailScreen
        let chart = chartArea
        let range = app.staticTexts["score-detail-chart-visible-range"].firstMatch
        let probe = selectionStateProbe
        XCTAssertTrue(chart.waitForExistence(timeout: 15))
        XCTAssertTrue(range.waitForExistence(timeout: 10) && probe.waitForExistence(timeout: 10))
        XCTAssertTrue(revealWhole(chart, in: scroll), "The actual chart must fit before point selection")
        XCTAssertEqual(probe.label, "none")
        let originalRange = range.label
        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.55))
        start.press(forDuration: 0.45, thenDragTo: end)
        XCTAssertNotEqual(probe.label, "none", "Long press must select a seeded chart date")
        XCTAssertFalse(probe.label.isEmpty)
        XCTAssertEqual(range.label, originalRange, "Point inspection must not move the visible period")
        XCTAssertTrue(app.descendants(matching: .any)[AXID.chartSelectionOverlay].firstMatch
            .waitForNonExistence(timeout: 2), "Selection overlay must clear after release")
        addScreenshotAttachment(named: "A02 actual chart date selected")
    }

    func testDarkMaximumAccessibilityKeepsFullContentReachable() {
        var configuration = launchConfiguration
        configuration.additionalArguments = [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "--ui-test-style", "dark", "--ui-disable-animations",
            "-morningBriefingDisabled", "YES"
        ]
        launchApp(with: configuration)
        openDetail()
        let scroll = detailScreen
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for id in ["training-readiness-detail-external-score", "training-readiness-detail-status",
                   "training-readiness-detail-evaluation-date",
                   "training-readiness-detail-factor-hrv", "training-readiness-detail-factor-sleep",
                   "training-readiness-detail-factor-rhr", "training-readiness-detail-factor-recovery",
                   "training-readiness-detail-factor-trend", "condition-time-phase-0",
                   "condition-time-phase-3", "score-detail-chart-visible-range"] {
            let item = app.descendants(matching: .any)[id].firstMatch
            XCTAssertTrue(revealWhole(item, in: scroll), "\(id) must fit at maximum text size")
        }
        addScreenshotAttachment(named: "A02 dark maximum AX hero and trend")
        let composition = app.descendants(matching: .any)["score-composition-card"].firstMatch
        XCTAssertTrue(composition.waitForExistence(timeout: 10))
        for factor in factors {
            let row = composition.descendants(matching: .staticText).matching(NSPredicate(
                format: "label CONTAINS %@ AND label CONTAINS %@", factor.title, factor.weight
            )).firstMatch
            XCTAssertTrue(revealWhole(row, in: scroll), "\(factor.title) original weight must be readable")
        }
        for bullet in calculationBullets {
            let item = app.staticTexts[bullet].firstMatch
            XCTAssertTrue(revealWhole(item, in: scroll), "The original calculation explanation must remain readable")
        }
        addScreenshotAttachment(named: "A02 dark maximum AX calculation complete")
        VisualAudit.capture("A02 dark maximum AX calculation complete")

        let back = app.navigationBars["Training Readiness"].buttons.firstMatch
        XCTAssertTrue(back.exists && back.isHittable, "Native Back must remain available")
        back.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
            .waitForExistence(timeout: 8), "Back must return to Activity")
    }

    private var detailScreen: XCUIElement {
        app.scrollViews[AXID.activityTrainingReadinessDetailScreen].firstMatch
    }

    private var trendCard: XCUIElement {
        detailScreen.descendants(matching: .any)["training-readiness-detail-trend-card"].firstMatch
    }

    private var chartArea: XCUIElement {
        trendCard.descendants(matching: .any)[AXID.trainingReadinessChartTrend].firstMatch
    }

    private func openDetail() {
        navigateToActivity()
        let hero = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15) && hero.isHittable)
        hero.auditTap()
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10))
    }

    private var factors: [(id: String, title: String, weight: String)] {
        [("hrv", "HRV Variability", "30%"),
         ("sleep", "Sleep Quality", "25%"),
         ("rhr", "Resting Heart Rate", "20%"),
         ("recovery", "Recovery Status", "15%"),
         ("trend", "Trend Bonus", "10%")]
    }

    private var calculationBullets: [String] {
        ["Final score = HRV(30%) + RHR(20%) + Sleep(25%) + Recovery(15%) + Trend(10%).",
         "Each component is normalized to 0-100 before weighting.",
         "HRV/RHR are compared against your personal baseline; positive trend increases score."]
    }

    private func statusName(for score: Int) -> String {
        switch score {
        case 80...100: "Ready to Train"
        case 60..<80: "Moderate"
        case 40..<60: "Light Activity"
        default: "Rest Day"
        }
    }

    private func lastScore(in label: String) -> Int? {
        let regex = try! NSRegularExpression(pattern: #"(?<![0-9])[0-9]{1,3}(?![0-9])"#)
        let range = NSRange(label.startIndex..., in: label)
        guard let match = regex.matches(in: label, range: range).last,
              let valueRange = Range(match.range, in: label) else { return nil }
        return Int(label[valueRange])
    }

    // Original AX propagates the chart identifier to UIKit probes. Scope to this
    // trend card and accept both direct probe IDs and propagated chart IDs.
    private var trendStateProbe: XCUIElement {
        trendCard.otherElements.matching(NSPredicate(
            format: "(identifier == %@ OR identifier == %@) AND label BEGINSWITH %@",
            "chart-trend-probe", AXID.trainingReadinessChartTrend, "trend-endpoints:"
        )).firstMatch
    }

    private var selectionStateProbe: XCUIElement {
        trendCard.otherElements.matching(NSPredicate(
            format: "(identifier == %@ OR identifier == %@) AND label != %@ AND NOT (label BEGINSWITH %@)",
            "chart-selection-probe", AXID.trainingReadinessChartTrend, "", "trend-endpoints:"
        )).firstMatch
    }

    private func waitForLabelChange(_ item: XCUIElement, from previous: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in item.exists && !item.label.isEmpty && item.label != previous },
            object: nil
        )
        return XCTWaiter.wait(for: [expectation], timeout: 15) == .completed
    }

    private func revealWhole(_ item: XCUIElement, in scroll: XCUIElement) -> Bool {
        guard scroll.waitForExistence(timeout: 8) else { return false }
        for attempt in 0..<24 {
            let viewport = unobscuredViewport(in: scroll)
            guard !viewport.isNull && viewport.height > 80 else { return false }
            let frame = item.exists ? item.frame : .null
            if !frame.isNull && frame.width > 0 && frame.height > 0
                && viewport.contains(frame) { return true }
            guard attempt < 23 else { break }
            let moveDown = !frame.isNull && frame.midY < viewport.midY
            let startY: CGFloat = moveDown ? 0.25 : 0.75
            let endY: CGFloat = moveDown ? 0.75 : 0.25
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: startY))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.05, dy: endY)
                ), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        return false
    }

    private func unobscuredViewport(in scroll: XCUIElement) -> CGRect {
        let window = app.windows.firstMatch.frame
        let intersection = scroll.frame.intersection(window)
        guard !intersection.isNull else { return .null }
        var top = intersection.minY
        var bottom = intersection.maxY
        for bar in app.navigationBars.allElementsBoundByIndex
            where bar.exists && bar.isHittable && bar.frame.minY < window.midY {
            top = max(top, bar.frame.maxY)
        }
        for bar in app.tabBars.allElementsBoundByIndex where bar.exists && bar.isHittable {
            if bar.frame.midY < window.midY { top = max(top, bar.frame.maxY) }
            else { bottom = min(bottom, bar.frame.minY) }
        }
        return CGRect(x: intersection.minX + 4, y: top + 4,
                      width: max(0, intersection.width - 8), height: max(0, bottom - top - 8))
    }
}
