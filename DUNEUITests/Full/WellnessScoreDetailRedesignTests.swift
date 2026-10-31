@preconcurrency import XCTest

/// H02 visual contract against the existing seeded Wellness score and real detail route.
@MainActor
final class WellnessScoreDetailRedesignTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "wellness" }
    override var additionalLaunchArguments: [String] {
        ["--ui-disable-animations", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
         "-morningBriefingDisabled", "YES"]
    }

    func testActualScoreComponentsAndNativeBack() {
        navigateToWellness()
        let root = app.descendants(matching: .any)[AXID.wellnessHeroScore].firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 15))
        let rootLabel = root.label
        let rootValue = root.value as? String ?? ""
        let components = ["sleep", "condition", "body", "posture"]
        let rootComponents = Dictionary(components.map { key in
            let row = app.descendants(matching: .any)["wellness-hero-component-\(key)"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 8), "Missing root \(key) component")
            return (key, row.label)
        }, uniquingKeysWith: { first, _ in first })

        root.auditTap()
        let detail = detailScreen
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        let hero = app.descendants(matching: .any)["wellness-detail-hero"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 8))
        let ring = app.descendants(matching: .any)["wellness-detail-hero-ring"].firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 8))
        XCTAssertEqual(ring.label, rootLabel, "Detail score and status must match the actual Wellness hero")
        let (score, status) = parseScoreAndStatus(from: ring.label)
        XCTAssertTrue((0...100).contains(score))
        XCTAssertEqual(status, statusName(for: score), "Status must follow the model's current score band")
        XCTAssertEqual(app.descendants(matching: .any)["wellness-detail-status"].firstMatch.label, status)
        XCTAssertEqual(app.descendants(matching: .any)["wellness-detail-status-icon"].firstMatch.label, status)
        let date = app.descendants(matching: .any)["wellness-detail-evaluation-date"].firstMatch
        XCTAssertTrue(date.exists && !date.label.isEmpty)
        XCTAssertTrue(rootValue.contains(date.label), "Detail must retain the root score's evaluation date")

        let titles = ["sleep": "Sleep", "condition": "Condition", "body": "Body", "posture": "Posture"]
        for key in components {
            let row = app.descendants(matching: .any)["wellness-detail-component-\(key)"].firstMatch
            XCTAssertTrue(row.exists, "Missing optional component slot: \(key)")
            XCTAssertTrue(row.label.contains(titles[key] ?? ""), "\(key) must retain its metric name")
            let rootValue = componentValue(from: rootComponents[key] ?? "")
            XCTAssertNotNil(rootValue, "Root \(key) must expose a score or unavailable mark")
            XCTAssertEqual(componentValue(from: row.label), rootValue,
                           "\(key) must preserve its actual optional score")
        }
        let composition = app.descendants(matching: .any)["score-composition-card"].firstMatch
        XCTAssertTrue(composition.exists)
        for (title, weight) in [("Sleep", "35%"), ("Condition", "30%"),
                                ("Body", "20%"), ("Posture", "15%")] {
            XCTAssertTrue(compositionRow(title: title, weight: weight, in: composition).exists,
                          "Missing original \(title) \(weight) composition row")
        }
        addScreenshotAttachment(named: "H02-native-actual-score-components")

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.exists && back.isHittable, "Native navigation back must be available")
        back.auditTap()
        XCTAssertTrue(root.waitForExistence(timeout: 8), "Back must return to the Wellness root")
        XCTAssertFalse(detail.exists)
    }

    func testFivePeriodsTrendAndConditionalExplanation() {
        openDetail()
        let trendCard = app.descendants(matching: .any)["wellness-detail-trend-card"].firstMatch
        XCTAssertTrue(trendCard.waitForExistence(timeout: 8))
        let period = app.segmentedControls.firstMatch
        let range = trendCard.staticTexts["score-detail-chart-visible-range"].firstMatch
        let toggle = trendCard.buttons["score-chart-trend-toggle"].firstMatch
        XCTAssertTrue(period.waitForExistence(timeout: 8))
        XCTAssertTrue(range.waitForExistence(timeout: 15))
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["wellness-chart-trend"].firstMatch
            .waitForExistence(timeout: 15), "Seeded week must render the actual chart")
        for key in ["hrv", "rhr", "sleep"] {
            XCTAssertTrue(app.descendants(matching: .any)["wellness-subscore-\(key)"].firstMatch.exists,
                          "Non-day history must preserve the \(key) subtrend")
        }

        let initialRange = range.label
        let scroll = app.scrollViews["wellness-score-detail-screen"].firstMatch
        let trendProbe = app.otherElements["chart-trend-probe"].firstMatch
        XCTAssertTrue(trendProbe.waitForExistence(timeout: 8))
        let initialTrend = trendProbe.label
        XCTAssertTrue(revealWhole(toggle, in: scroll) && toggle.isHittable)
        toggle.auditTap()
        XCTAssertTrue(waitForLabelChange(trendProbe, from: initialTrend),
                      "Trend toggle must change the chart's computed trend endpoints")
        for title in ["D", "W", "M", "6M", "Y"] {
            let option = period.buttons[title]
            XCTAssertTrue(option.exists, "Missing \(title) period")
            XCTAssertTrue(revealWhole(option, in: scroll) && option.isHittable,
                          "\(title) must be fully visible before selection")
            let wasSelected = option.isSelected
            let previousRange = range.label
            option.auditTap()
            XCTAssertTrue(option.isSelected, "\(title) must become selected")
            if !wasSelected {
                XCTAssertTrue(waitForLabelChange(range, from: previousRange),
                              "\(title) must update the visible date range")
            }
            if title == "D" {
                for key in ["hrv", "rhr", "sleep"] {
                    XCTAssertFalse(app.descendants(matching: .any)["wellness-subscore-\(key)"].firstMatch.exists,
                                   "Day uses rolling snapshots without the non-day \(key) subtrend")
                }
                XCTAssertNotEqual(range.label, initialRange)
            } else {
                for key in ["hrv", "rhr", "sleep"] {
                    XCTAssertTrue(app.descendants(matching: .any)["wellness-subscore-\(key)"].firstMatch.exists)
                }
            }
        }
        XCTAssertTrue(app.staticTexts["Calculation Method"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Condition Calculation"].firstMatch.exists,
                       "Default seed has no ConditionScoreDetail; its card is conditional")
        XCTAssertTrue(app.staticTexts["Body Calculation"].firstMatch.exists,
                      "The seeded body trend must keep its calculation card")
        XCTAssertTrue(app.staticTexts["Final Score"].firstMatch.exists)
        for bullet in [
            "Final score = weighted average of Sleep(35%), Condition(30%), Body(20%), and Posture(15%).",
            "Sleep and Condition come from Apple Watch signals, then normalized to 0-100.",
            "Body score is derived from 7-day trend stability and direction changes.",
            "Posture score reflects your latest posture assessment result (0-100).",
            "If any component is missing, remaining weights are re-normalized before final scoring."
        ] {
            XCTAssertTrue(app.staticTexts[bullet].firstMatch.exists, "Missing original calculation explanation")
        }
        addScreenshotAttachment(named: "H02-native-period-trend-and-method")
    }

    func testConditionCalculationPositiveFixtureKeepsMeasuredBranches() {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["--ui-visual-condition-components-fixture"]
        launchApp(with: configuration)
        openDetail()
        XCTAssertTrue(app.staticTexts["Condition Calculation"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Today HRV"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Baseline HRV"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Today RHR"].firstMatch.exists,
                      "The explicit fixture provides today's RHR")
        XCTAssertTrue(app.staticTexts["Calculation Method"].firstMatch.exists)
        addScreenshotAttachment(named: "H02-native-condition-calculation-positive-fixture")
    }

    func testDarkMaximumAccessibilityWholeContentReachability() {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["--ui-test-style", "dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchApp(with: configuration)
        openDetail()
        let scroll = app.scrollViews["wellness-score-detail-screen"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        for id in ["wellness-detail-external-score", "wellness-detail-status",
                   "wellness-detail-component-sleep", "wellness-detail-component-condition",
                   "wellness-detail-component-body", "wellness-detail-component-posture",
                   "condition-time-phase-0", "condition-time-phase-3",
                   "score-detail-chart-visible-range"] {
            let item = app.descendants(matching: .any)[id].firstMatch
            XCTAssertTrue(revealWhole(item, in: scroll), "\(id) must fit in the viewport at maximum text size")
            addScreenshotAttachment(named: "H02-dark-max-AX-\(id)")
        }
        let composition = app.descendants(matching: .any)["score-composition-card"].firstMatch
        XCTAssertTrue(composition.exists)
        for (title, weight) in [("Sleep", "35%"), ("Condition", "30%"),
                                ("Body", "20%"), ("Posture", "15%")] {
            XCTAssertTrue(revealWhole(compositionRow(title: title, weight: weight, in: composition), in: scroll),
                          "Original \(title) \(weight) row must remain readable")
        }
        XCTAssertTrue(revealWhole(app.staticTexts["Calculation Method"].firstMatch, in: scroll))
        XCTAssertTrue(revealWhole(app.staticTexts[
            "If any component is missing, remaining weights are re-normalized before final scoring."
        ].firstMatch, in: scroll))
        addScreenshotAttachment(named: "H02-dark-max-AX-full-method")
    }

    func testExistingChartPointSelectionRemainsAvailable() {
        openDetail()
        let scroll = app.scrollViews["wellness-score-detail-screen"].firstMatch
        let chart = app.descendants(matching: .any)["wellness-chart-trend"].firstMatch
        let probe = app.otherElements["chart-selection-probe"].firstMatch
        let visibleRange = app.staticTexts["score-detail-chart-visible-range"].firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 15))
        XCTAssertTrue(probe.waitForExistence(timeout: 8))
        XCTAssertTrue(visibleRange.waitForExistence(timeout: 8))
        XCTAssertTrue(revealWhole(chart, in: scroll), "Week chart must fit before selecting a point")
        XCTAssertEqual(probe.label, "none", "No point should be selected before the gesture")
        let beforeRange = visibleRange.label
        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.55))
        start.press(forDuration: 0.45, thenDragTo: end)
        XCTAssertNotEqual(probe.label, "none", "Long press must select a seeded chart date")
        XCTAssertFalse(probe.label.isEmpty, "Selected date readback must have content")
        XCTAssertEqual(visibleRange.label, beforeRange,
                       "Inspecting a point must not scroll the visible date range")
        XCTAssertTrue(app.descendants(matching: .any)["chart-selection-overlay"].firstMatch
            .waitForNonExistence(timeout: 2), "Selection overlay must clear after release")
        addScreenshotAttachment(named: "H02-native-chart-selected-date-readback")
    }

    private var detailScreen: XCUIElement {
        app.descendants(matching: .any)["wellness-score-detail-screen"].firstMatch
    }

    private func openDetail() {
        navigateToWellness()
        let root = app.descendants(matching: .any)[AXID.wellnessHeroScore].firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 15))
        root.auditTap()
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10))
    }

    private func parseScoreAndStatus(from label: String) -> (Int, String) {
        let pattern = #"Wellness score ([0-9]{1,3}), (Excellent|Good|Fair|Tired|Warning)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(label.startIndex..., in: label)
        guard let match = regex.firstMatch(in: label, range: range),
              let scoreRange = Range(match.range(at: 1), in: label),
              let statusRange = Range(match.range(at: 2), in: label),
              let score = Int(label[scoreRange]) else {
            XCTFail("Unrecognized native score/status label: \(label)")
            return (-1, "")
        }
        return (score, String(label[statusRange]))
    }

    private func statusName(for score: Int) -> String {
        switch score {
        case 80...100: "Excellent"
        case 60..<80: "Good"
        case 40..<60: "Fair"
        case 20..<40: "Tired"
        default: "Warning"
        }
    }

    private func componentValue(from label: String) -> String? {
        if label.contains("—") { return "—" }
        let regex = try! NSRegularExpression(pattern: #"(?<![0-9])[0-9]{1,3}(?![0-9])"#)
        let range = NSRange(label.startIndex..., in: label)
        guard let match = regex.matches(in: label, range: range).last,
              let valueRange = Range(match.range, in: label) else { return nil }
        return String(label[valueRange])
    }

    private func compositionRow(title: String, weight: String, in card: XCUIElement) -> XCUIElement {
        card.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@", title, weight
        )).firstMatch
    }

    private func revealWhole(_ item: XCUIElement, in scroll: XCUIElement) -> Bool {
        guard scroll.waitForExistence(timeout: 8) else { return false }
        for check in 0..<10 {
            let viewport = unobscuredViewport(in: scroll)
            let frame = item.exists ? item.frame : .null
            if !frame.isNull && frame.width > 0 && frame.height > 0
                && viewport.contains(frame) { return true }
            guard check < 9 else { break }
            let moveDown = !frame.isNull && frame.midY < viewport.midY
            let startY: CGFloat = moveDown ? 0.25 : 0.75
            let endY: CGFloat = moveDown ? 0.75 : 0.25
            // The outer gutter stays clear of nested chart gesture recognizers.
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: startY))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.05, dy: endY)
                ), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        return false
    }

    private func unobscuredViewport(in scroll: XCUIElement) -> CGRect {
        let window = app.windows.firstMatch.frame
        let scrollFrame = scroll.frame
        let intersection = scrollFrame.intersection(window)
        guard !intersection.isNull else { return .null }
        var top = intersection.minY
        var bottom = intersection.maxY
        for bar in app.navigationBars.allElementsBoundByIndex
            where bar.exists && bar.isHittable && bar.frame.minY < window.midY {
            top = max(top, bar.frame.maxY)
        }
        for bar in app.tabBars.allElementsBoundByIndex where bar.exists && bar.isHittable {
            if bar.frame.midY < window.midY {
                top = max(top, bar.frame.maxY)
            } else {
                bottom = min(bottom, bar.frame.minY)
            }
        }
        return CGRect(x: window.minX + 4, y: top + 4, width: max(0, window.width - 8),
                      height: max(0, bottom - top - 8))
    }

    private func waitForLabelChange(_ item: XCUIElement, from previous: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in item.exists && !item.label.isEmpty && item.label != previous },
            object: nil
        )
        return XCTWaiter.wait(for: [expectation], timeout: 15) == .completed
    }
}
