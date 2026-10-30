@preconcurrency import XCTest

/// Exercises the real native query view with isolated, synthetic UI evidence.
@MainActor
final class HealthQuerySmokeTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "today" }

    override var additionalLaunchArguments: [String] {
        ["--ui-health-query-fixture", "-morningBriefingDisabled", "YES",
         "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testBrowseEntryPeriodSourceAndBack() {
        openBrowse()
        XCTAssertTrue(element("health-query-result-kind-latestWorkout").waitForExistence(timeout: 8))
        XCTAssertTrue(app.scrollToElementIfNeeded("health-query-source", maxSwipes: 8))
        XCTAssertTrue(element("health-query-source").exists, "A loaded answer should show its provenance")

        selectPeriod("last7Days")
        XCTAssertTrue(element("health-query-result-kind-latestWorkout").waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Period:")).firstMatch.exists)

        let done = app.buttons["health-query-done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertFalse(element("health-query-screen").waitForExistence(timeout: 2))
        XCTAssertTrue(element("health-qa-browse-records").waitForExistence(timeout: 5),
                      "Back navigation should restore the Q&A inspector")
    }

    func testNoDataIsExplicit() {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-health-query-no-data")
        launchApp(with: configuration)
        openBrowse()
        XCTAssertTrue(element("health-query-result").waitForExistence(timeout: 8))
        XCTAssertTrue(element("health-query-no-data").exists)
        XCTAssertFalse(element("health-query-source").exists)
        capture("SQ00-no-data")
    }

    /// One launch captures every supported information choice. The source metadata
    /// records that these are native simulator screens populated by a test fixture.
    func testCaptureAllQueryKinds() {
        openBrowse()
        let kinds = [
            "latestWorkout", "workoutSummary", "strengthSets", "personalRecord",
            "cardioDetail", "latestBody", "bodyTrend", "sleep", "condition",
            "metricComparison", "workoutComparison", "memoSearch", "report", "longAnalysis"
        ]
        for (index, kind) in kinds.enumerated() {
            if index > 0 { selectKind(kind) }
            XCTAssertTrue(element("health-query-result-kind-\(kind)").waitForExistence(timeout: 8),
                          "Loaded fixture should match \(kind)")
            XCTAssertTrue(element("health-query-source").exists, "Loaded \(kind) should name its source")
            capture(String(format: "SQ%02d-%@", index + 1, kind))
        }
    }

    func testReportPreviewShareCancel() {
        openBrowse()
        selectKind("report")
        XCTAssertTrue(element("health-query-result-kind-report").waitForExistence(timeout: 8))
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("health-query-preview-report", maxSwipes: 12))
        app.buttons["health-query-preview-report"].firstMatch.tap()
        XCTAssertTrue(element("health-query-report-preview").waitForExistence(timeout: 5))
        capture("SQ13-report-preview")

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("health-query-share", maxSwipes: 8))
        app.buttons["health-query-share"].firstMatch.tap()
        let dismissShare = app.buttons["header.closeButton"].firstMatch
        XCTAssertTrue(dismissShare.waitForExistence(timeout: 8), "System share sheet should open")
        capture("SQ13-report-share")
        dismissShare.tap()
        XCTAssertTrue(element("health-query-report-preview").waitForExistence(timeout: 5),
                      "Cancelling system share should return to the report")
    }

    private func openBrowse() {
        navigateToDashboard()
        let cardID = "dashboard-health-qa-card"
        XCTAssertTrue(app.scrollToElementIfNeeded(cardID, maxSwipes: 18))
        let card = element(cardID)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let browse = element("health-qa-browse-records")
        XCTAssertTrue(browse.waitForExistence(timeout: 8))
        browse.tap()
        XCTAssertTrue(element("health-query-screen").waitForExistence(timeout: 8))
    }

    private func selectKind(_ kind: String) {
        let picker = element("health-query-kind")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("health-query-kind", maxSwipes: 8))
        picker.tap()
        let choice = app.buttons["health-query-kind-\(kind)"].firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "Information menu should offer \(kind)")
        choice.tap()
    }

    private func selectPeriod(_ period: String) {
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("health-query-period", maxSwipes: 8))
        element("health-query-period").tap()
        let choice = app.buttons["health-query-period-\(period)"].firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func capture(_ name: String) {
        if ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_HOST_ONLY"] == "1" {
            VisualAudit.capture(name)
        } else {
            addScreenshotAttachment(named: name)
        }
    }
}
