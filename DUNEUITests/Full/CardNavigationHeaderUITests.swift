@preconcurrency import XCTest

/// The four main tabs keep their existing detail routes when the trailing,
/// otherwise empty part of a card header is tapped.
@MainActor
final class CardNavigationHeaderUITests: SeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["-morningBriefingDisabled", "YES", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
         "--ui-test-theme", "desertWarm", "--ui-test-style", "light",
         "--ui-design-map-sleep-prediction"]
    }

    func testTodaySleepHeaderOpensSleepDetail() {
        navigateToDashboard()
        captureInitialRoot("Today", hero: AXID.dashboardHeroCondition)
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("dashboard-recovery-sleep-details", maxSwipes: 16))
        XCTAssertFalse(app.staticTexts["수면 상세"].exists,
                       "The old sleep footer action should not duplicate the header route")
        tapTrailingHeader(in: "dashboard-recovery-sleep-details", tab: "Today",
                          maxSwipes: 16, usesLinkAsHeader: true)

        XCTAssertTrue(app.descendants(matching: .any)[AXID.metricDetailScreen("sleep")].firstMatch
            .waitForExistence(timeout: 8), "The sleep header should keep the sleep metric route")
        addScreenshotAttachment(named: "Card header Today sleep detail")
    }

    func testActivityMuscleMapHeaderOpensMuscleMapDetail() {
        navigateToActivity()
        captureInitialRoot("Activity", hero: AXID.activityHeroReadiness)
        let linkID = AXID.activityMuscleMapDetailLink
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(linkID, maxSwipes: 8))
        let section = app.descendants(matching: .any)[AXID.activitySectionMuscleMap].firstMatch
        XCTAssertFalse(section.staticTexts["상세 보기"].exists,
                       "The old body detail action should not duplicate the header route")
        tapTrailingHeader(in: linkID, tab: "Activity", maxSwipes: 8, usesLinkAsHeader: true)

        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityMuscleMapDetailScreen].firstMatch
            .waitForExistence(timeout: 8), "The muscle map header should keep the muscle map route")
        addScreenshotAttachment(named: "Card header Activity muscle map detail")
    }

    func testWellnessSleepPredictionHeaderOpensDetail() {
        navigateToWellness()
        captureInitialRoot("Wellness", hero: AXID.wellnessHeroScore)
        let linkID = "wellness-sleep-prediction-detail-link"
        tapTrailingHeader(in: linkID, tab: "Wellness", maxSwipes: 8, usesLinkAsHeader: true)

        XCTAssertTrue(app.descendants(matching: .any)["wellness-sleep-prediction-detail-screen"].firstMatch
            .waitForExistence(timeout: 8), "The prediction header should keep the sleep prediction route")
        addScreenshotAttachment(named: "Card header Wellness sleep prediction detail")
    }

    func testLifeWeeklyReportHeaderOpensReport() {
        navigateToLife()
        captureInitialRoot("Life", hero: AXID.lifeHeroProgress)
        let linkID = "life-weekly-report-button"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(linkID, maxSwipes: 10))
        XCTAssertFalse(app.staticTexts["주간 리포트 보기"].exists,
                       "The old report footer action should not duplicate the header route")
        tapTrailingHeader(in: linkID, tab: "Life", maxSwipes: 10)

        XCTAssertTrue(app.scrollViews["life-weekly-report-scroll"].firstMatch
            .waitForExistence(timeout: 8), "The weekly report header should keep the report route")
        addScreenshotAttachment(named: "Card header Life weekly report detail")
    }

    private func captureInitialRoot(_ tab: String, hero identifier: String) {
        XCTAssertTrue(app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: 10),
                      "\(tab) should load before capturing its initial viewport")
        addScreenshotAttachment(named: "Card header \(tab) initial root")
    }

    private func tapTrailingHeader(in linkID: String, tab: String, maxSwipes: Int,
                                   usesLinkAsHeader: Bool = false) {
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(linkID, maxSwipes: maxSwipes),
                      "\(tab) detail link should be reachable")
        let link = app.buttons[linkID].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "\(tab) detail link should keep its identifier")
        let header = usesLinkAsHeader
            ? link
            : link.descendants(matching: .any)["card-navigation-header"].firstMatch
        if !usesLinkAsHeader {
            XCTAssertTrue(header.waitForExistence(timeout: 5), "\(tab) link should expose the shared header")
        }

        let scroll = app.scrollViews.firstMatch
        for _ in 0..<maxSwipes where !header.isHittable {
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
            if header.frame.maxY < viewport.minY {
                scroll.swipeDown(velocity: .slow)
            } else {
                scroll.swipeUp(velocity: .slow)
            }
        }
        XCTAssertTrue(header.isHittable, "\(tab) header should be visible before tapping")
        if usesLinkAsHeader {
            XCTAssertGreaterThanOrEqual(header.frame.height, 44,
                                        "\(tab) link should expose the complete header hit area")
            XCTAssertLessThanOrEqual(header.frame.height, 100,
                                     "\(tab) link should remain a header-sized control")
        }
        XCTAssertGreaterThan(header.frame.width, 88,
                             "\(tab) header should provide space beyond the title and chevron")
        addScreenshotAttachment(named: "Card header \(tab) root")
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }
}
