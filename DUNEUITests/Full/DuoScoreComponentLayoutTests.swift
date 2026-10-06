@preconcurrency import XCTest

/// Numeric layout gates for the four consumers of ScoreCompositionCard.
@MainActor
final class DuoScoreComponentLayoutTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "today" }
    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-morningBriefingDisabled", "YES"
        ]
    }

    func testStressContributorsAndCompositionAcrossFoldStates() throws {
        guard VisualAudit.isEnabled,
              ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_FOLD"] == "1" else {
            throw XCTSkip("Opt-in fold and native score composition audit only")
        }
        executionTimeAllowance = 600
        launchSeededTab("today", extraArguments: ["--ui-visual-stress-fixture"])
        openDetail(from: "dashboard-stress-score", screen: "cumulative-stress-detail-screen")

        let scroll = app.scrollViews["cumulative-stress-detail-screen"].firstMatch
        let expected: [(factor: String, score: String, weight: String)] = [
            ("hrvVariability", "10", "40%"),
            ("sleepConsistency", "1", "35%"),
            ("activityLoad", "20", "25%")
        ]
        for state in ["closed", "partiallyOpen", "openFlat"] {
            VisualAudit.capture("FOLD:\(state)")
            XCTAssertTrue(scroll.waitForExistence(timeout: 8), "Stress detail should survive \(state)")
            for item in expected {
                let score = app.staticTexts["stress-contribution-score-\(item.factor)"].firstMatch
                XCTAssertTrue(revealWhole(score, in: scroll), "\(item.factor) contributor should fit after \(state)")
                XCTAssertEqual(score.label, item.score, "\(item.factor) contributor should keep its seeded value")
                let weight = nearestWeight(item.weight, to: score)
                XCTAssertNotNil(weight, "\(item.factor) should retain its weight label")
                if let weight {
                    assertSingleLine(score, against: weight, description: "\(state) \(item.factor) contributor")
                    let icon = app.images["stress-contribution-icon-\(item.factor)"].firstMatch
                    XCTAssertTrue(icon.exists, "The contributor icon should be exposed")
                    XCTAssertLessThanOrEqual(icon.frame.maxX, weight.frame.minX,
                                             "The contributor icon should not overlap its weight")
                }
                VisualAudit.capture("Stress \(state) \(item.factor) contributor score \(item.score) whole frame")
                let detail = app.staticTexts["stress-contribution-detail-\(item.factor)"].firstMatch
                XCTAssertTrue(revealWhole(detail, in: scroll), "The full contributor detail should be visible")
                VisualAudit.capture("Stress \(state) \(item.factor) full contributor detail")
            }

            let card = app.descendants(matching: .any)["score-composition-card"].firstMatch
            XCTAssertTrue(revealCardContent(card, in: scroll), "Shared stress composition should be reachable")
            for item in expected {
                let score = card.staticTexts[item.score].firstMatch
                let weight = card.staticTexts[item.weight].firstMatch
                XCTAssertTrue(revealWhole(score, in: scroll), "Shared \(item.factor) score should fit after \(state)")
                XCTAssertEqual(score.label, item.score, "Shared \(item.factor) score should match the fixture")
                XCTAssertTrue(weight.exists, "Shared \(item.factor) weight should be exposed")
                assertSingleLine(score, against: weight, description: "\(state) shared \(item.factor)")
                VisualAudit.capture("Stress \(state) shared \(item.factor) score \(item.score) whole frame")
            }
        }
    }

    func testConditionCompositionScoresFitAtMaximumTextSize() throws {
        try auditSharedComposition(tab: "today", hero: AXID.dashboardHeroCondition,
                                   screen: AXID.conditionScoreDetailScreen, route: "Condition",
                                   extraArguments: ["--ui-visual-condition-components-fixture"])
    }

    func testWellnessCompositionScoresFitAtMaximumTextSize() throws {
        try auditSharedComposition(tab: "wellness", hero: AXID.wellnessHeroScore,
                                   screen: AXID.wellnessScoreDetailScreen, route: "Wellness")
    }

    func testReadinessCompositionScoresFitAtMaximumTextSize() throws {
        try auditSharedComposition(tab: "train", hero: AXID.activityHeroReadiness,
                                   screen: AXID.activityTrainingReadinessDetailScreen, route: "Readiness")
    }

    func testReadinessSubscoreChartsFitAtMaximumTextSize() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in native Readiness subscore chart audit only") }
        executionTimeAllowance = 600
        launchSeededTab("train")
        openDetail(from: AXID.activityHeroReadiness, screen: AXID.activityTrainingReadinessDetailScreen)
        auditSubscoreCharts(
            screen: AXID.activityTrainingReadinessDetailScreen,
            route: "Readiness",
            sections: [
                ("training-readiness-subscore-hrv", "HRV", "HRV"),
                ("training-readiness-subscore-rhr", "Resting Heart Rate", "RHR"),
                ("training-readiness-subscore-sleep", "Sleep Duration", "Sleep")
            ]
        )
    }

    func testWellnessSubscoreChartsFitAtMaximumTextSize() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in native Wellness subscore chart audit only") }
        executionTimeAllowance = 600
        launchSeededTab("wellness")
        openDetail(from: AXID.wellnessHeroScore, screen: AXID.wellnessScoreDetailScreen)

        auditSubscoreCharts(
            screen: AXID.wellnessScoreDetailScreen,
            route: "Wellness",
            sections: [
                ("wellness-subscore-hrv", "HRV", "HRV"),
                ("wellness-subscore-rhr", "Resting Heart Rate", "RHR"),
                ("wellness-subscore-sleep", "Sleep Duration", "Sleep")
            ]
        )
    }

    func testConditionSubscoreChartsFitAtMaximumTextSize() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in native Condition subscore chart audit only") }
        executionTimeAllowance = 600
        launchSeededTab("today", extraArguments: ["--ui-visual-condition-components-fixture"])
        openDetail(from: AXID.dashboardHeroCondition, screen: AXID.conditionScoreDetailScreen)

        auditSubscoreCharts(
            screen: AXID.conditionScoreDetailScreen,
            route: "Condition",
            sections: [
                ("condition-subscore-hrv", "HRV", "HRV"),
                ("condition-subscore-rhr", "Resting Heart Rate", "RHR")
            ]
        )
    }

    private func auditSubscoreCharts(
        screen: String,
        route: String,
        sections: [(identifier: String, title: String, metric: String)]
    ) {
        let scroll = app.scrollViews[screen].firstMatch
        for (identifier, title, metric) in sections {
            let section = scroll.descendants(matching: .any)[identifier].firstMatch
            XCTAssertTrue(section.waitForExistence(timeout: 15), "\(metric) subscore should render in week mode")

            let header = section.staticTexts[title].firstMatch
            let average = section.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Avg ")).firstMatch
            XCTAssertTrue(revealWhole(header, in: scroll), "\(metric) heading should fit in the viewport")
            XCTAssertTrue(revealWhole(average, in: scroll), "\(metric) average should fit in the viewport")
            VisualAudit.capture("\(route) maximum AX \(metric) header and average")

            let plot = section.descendants(matching: .any)["subscore-trend-plot"].firstMatch
            XCTAssertTrue(plot.waitForExistence(timeout: 8), "\(metric) chart plot should be exposed")
            XCTAssertGreaterThan(plot.frame.width, 0, "\(metric) plot should have a rendered width")
            XCTAssertGreaterThan(plot.frame.height, 0, "\(metric) plot should have a rendered height")
            XCTAssertTrue(revealWhole(plot, in: scroll), "The entire \(metric) plot should fit in the viewport")
            VisualAudit.capture("\(route) maximum AX \(metric) complete chart plot")
        }
    }

    private func auditSharedComposition(tab: String, hero: String, screen: String, route: String,
                                       extraArguments: [String] = []) throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in native score composition audit only") }
        launchSeededTab(tab, extraArguments: extraArguments)
        openDetail(from: hero, screen: screen)
        let scroll = app.scrollViews[screen].firstMatch
        let card = app.descendants(matching: .any)["score-composition-card"].firstMatch
        XCTAssertTrue(revealCardContent(card, in: scroll), "\(route) shared composition should be reachable")

        let numeric = card.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]{1,3}$"))
            .allElementsBoundByIndex
        XCTAssertFalse(numeric.isEmpty, "\(route) should expose at least one populated component score")
        let weights = card.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]{1,3}%$"))
            .allElementsBoundByIndex
        XCTAssertFalse(weights.isEmpty, "\(route) should expose component weight references")
        var populated = 0
        for score in numeric {
            XCTAssertTrue(revealWhole(score, in: scroll), "\(route) component score should fit in the viewport")
            let value = try XCTUnwrap(Int(score.label), "Component score should be numeric")
            XCTAssertTrue((0...100).contains(value), "\(route) component score should be within 0...100")
            if route == "Condition" { XCTAssertEqual(value, 100, "Condition should retain the three-digit fixture") }
            if value > 0 { populated += 1 }
            let reference = weights.min { abs($0.frame.midY - score.frame.midY) < abs($1.frame.midY - score.frame.midY) }
            if let reference { assertSingleLine(score, against: reference, description: "\(route) component") }
            VisualAudit.capture("\(route) component score \(value) whole frame")
        }
        XCTAssertGreaterThan(populated, 0, "\(route) should show a nonzero seeded score")
        VisualAudit.capture("\(route) shared composition lower viewport")
    }

    private func launchSeededTab(_ tab: String, extraArguments: [String] = []) {
        var configuration = launchConfiguration
        configuration.initialTabSelectionArgument = tab
        configuration.additionalArguments += extraArguments
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8), "\(tab) should load its seeded root")
    }

    private func openDetail(from entryID: String, screen: String) {
        let entry = app.descendants(matching: .any)[entryID].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(entryID, maxSwipes: 12),
                      "\(entryID) should be reachable")
        entry.auditTap()
        XCTAssertTrue(app.scrollViews[screen].firstMatch.waitForExistence(timeout: 10),
                      "\(screen) should open")
    }

    private func revealCardContent(_ card: XCUIElement, in scroll: XCUIElement) -> Bool {
        guard scroll.waitForExistence(timeout: 8) else { return false }
        for _ in 0..<20 {
            if card.exists && card.staticTexts.firstMatch.exists { return true }
            scroll.swipeUp(velocity: .slow)
        }
        return card.exists && card.staticTexts.firstMatch.exists
    }

    private func revealWhole(_ element: XCUIElement, in scroll: XCUIElement) -> Bool {
        guard scroll.waitForExistence(timeout: 8) else { return false }
        for _ in 0..<20 {
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 4)
            if element.exists && viewport.contains(element.frame) { return true }
            if element.exists && viewport.height > 0 {
                let delta = element.frame.midY - viewport.midY
                let travel = min(max(abs(delta), 20), viewport.height * 0.25) / scroll.frame.height
                let startY: CGFloat = delta < 0 ? 0.3 : 0.7
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                    .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: startY + (delta < 0 ? travel : -travel))
                    ), withVelocity: .slow, thenHoldForDuration: 0.2)
            } else {
                scroll.swipeUp(velocity: .slow)
            }
        }
        return element.exists
            && scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 4).contains(element.frame)
    }

    private func nearestWeight(_ label: String, to score: XCUIElement) -> XCUIElement? {
        app.staticTexts.matching(NSPredicate(format: "label == %@", label)).allElementsBoundByIndex.min {
            abs($0.frame.midY - score.frame.midY) < abs($1.frame.midY - score.frame.midY)
        }
    }

    private func assertSingleLine(_ score: XCUIElement, against weight: XCUIElement, description: String) {
        XCTAssertTrue(weight.exists && weight.frame.height > 0, "\(description) weight reference should exist")
        XCTAssertLessThanOrEqual(score.frame.height, weight.frame.height * 1.35,
                                 "\(description) number should remain one caption line")
    }
}
