@preconcurrency import XCTest

/// The seeded root covers the Activity reading order and the four tab headings.
/// Native captures are kept in separate selectors for the design-map runner.
@MainActor
final class ActivityFlowUITests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "train" }

    override var additionalLaunchArguments: [String] {
        ["-morningBriefingDisabled", "YES",
         "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
         "--ui-test-theme", "desertWarm", "--ui-test-style", "light",
         "--ui-design-map-activity-routes"]
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func testActivityRootReadinessAndFlowOrder() {
        navigateToActivity()

        XCTAssertTrue(waitForElement("activity-hero-readiness", timeout: 15).exists)
        XCTAssertTrue(waitForElement("activity-hero-components", timeout: 15).exists,
                      "The readiness evidence bars should be present in the seeded state")
        XCTAssertEqual(waitForElement("activity-hero-heading").label, "READINESS")
        XCTAssertFalse(element("activity-musclemap-3d-link").exists,
                       "The Activity root should not offer a direct 3D route")

        // Capture all eager VStack frames before scrolling: viewport coordinates
        // shift on every swipe, while regular layouts place related cards in pairs.
        let sectionIDs = [
            "activity-section-musclemap",
            "activity-section-injuryrisk",
            "activity-section-suggested",
            "activity-section-recent",
            "activity-section-pr",
            "activity-section-achievement",
            "activity-section-weeklystats",
            "activity-section-weeklyreport",
            "activity-section-consistency",
            "activity-section-volume",
            "activity-section-exercisemix"
        ]
        var frames: [String: CGRect] = [:]
        for identifier in sectionIDs {
            let section = waitForElement(identifier, timeout: 10)
            XCTAssertGreaterThan(section.frame.height, 0, "\(identifier) should have a visible layout frame")
            frames[identifier] = section.frame
        }
        func frame(_ identifier: String) -> CGRect { frames[identifier] ?? .zero }
        func assertBelow(_ later: String, _ earlier: String) {
            XCTAssertGreaterThan(frame(later).minY + 2, frame(earlier).minY,
                                 "\(later) should follow \(earlier)")
        }
        func assertSameRow(_ first: String, _ second: String) {
            XCTAssertLessThan(abs(frame(first).minY - frame(second).minY), 40,
                              "\(first) and \(second) should begin in the same row")
        }

        let map = "activity-section-musclemap"
        let risk = "activity-section-injuryrisk"
        let suggested = "activity-section-suggested"
        let recent = "activity-section-recent"
        let pr = "activity-section-pr"
        let achievement = "activity-section-achievement"
        let stats = "activity-section-weeklystats"
        let report = "activity-section-weeklyreport"
        let consistency = "activity-section-consistency"
        let volume = "activity-section-volume"
        let mix = "activity-section-exercisemix"

        let isPaired = frame(suggested).minX > frame(risk).minX + 80
        assertBelow(risk, map)
        if isPaired {
            assertSameRow(map, suggested)
            XCTAssertLessThan(frame(risk).minX, frame(suggested).minX)
            assertBelow(recent, risk)
            assertBelow(recent, suggested)
            assertBelow(pr, recent)
            assertSameRow(pr, achievement)
            assertBelow(stats, pr)
            assertBelow(stats, achievement)
            assertSameRow(stats, report)
            assertBelow(consistency, stats)
            assertBelow(consistency, report)
            assertSameRow(consistency, volume)
            assertBelow(mix, consistency)
            assertBelow(mix, volume)
        } else {
            for (earlier, later) in zip(sectionIDs, sectionIDs.dropFirst()) {
                assertBelow(later, earlier)
            }
        }
    }

    func testRootMuscleMapModesAndLegends() {
        navigateToActivity()
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-muscle-map-mode", maxSwipes: 8))
        XCTAssertTrue(element("musclemap-body-front-chest").exists)
        XCTAssertTrue(element("musclemap-body-back-traps").exists)

        tapSegment(in: "activity-muscle-map-mode", index: 0)
        XCTAssertTrue(waitForElement("activity-muscle-map-legend-recovery").exists)
        tapSegment(in: "activity-muscle-map-mode", index: 1)
        XCTAssertTrue(waitForElement("activity-muscle-map-legend-sets").exists)
        XCTAssertFalse(element("activity-muscle-map-legend-recovery").exists)
        tapSegment(in: "activity-muscle-map-mode", index: 0)
        XCTAssertTrue(waitForElement("activity-muscle-map-legend-recovery").exists)
    }

    func testReadinessHeaderTrailingEdgeOpensDetail() {
        navigateToActivity()
        let header = app.buttons["activity-hero-readiness"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 15))
        XCTAssertTrue(header.isEnabled, "The seeded readiness should retain its detail route")
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.12)).tap()
        XCTAssertTrue(waitForElement(AXID.activityTrainingReadinessDetailScreen, timeout: 10).exists)
    }

    func testPersonalRecordsHeaderTrailingEdgeOpensDetail() {
        navigateToActivity()
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-section-pr", maxSwipes: 16))
        let header = app.buttons["activity-section-pr"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(header.frame.height, 44)
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(waitForElement("activity-personal-records-detail-screen", timeout: 10).exists)
    }

    func testFourTabHeroHeadingsUseFixedEnglish() {
        let headings: [(tab: String, hero: String, heading: String, title: String)] = [
            ("Today", AXID.dashboardHeroCondition, "dashboard-hero-heading", "CONDITION"),
            ("Activity", AXID.activityHeroReadiness, "activity-hero-heading", "READINESS"),
            ("Wellness", AXID.wellnessHeroScore, "wellness-hero-heading", "WELLNESS"),
            ("Life", AXID.lifeHeroProgress, "life-hero-heading", "HABITS")
        ]
        for item in headings {
            app.navigateToTab(item.tab)
            XCTAssertTrue(waitForElement(item.hero, timeout: 15).exists)
            XCTAssertEqual(waitForElement(item.heading).label, item.title,
                           "\(item.tab) should retain its fixed English hero heading")
        }
    }

    func testCaptureA01SeededFlow() {
        captureA01Flow(suffix: "")
    }

    func testCaptureA01DarkFlow() {
        var configuration = launchConfiguration
        if let styleIndex = configuration.additionalArguments.firstIndex(of: "--ui-test-style") {
            configuration.additionalArguments[styleIndex + 1] = "dark"
        }
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        captureA01Flow(suffix: "-dark")
    }

    func testCaptureA01MaximumAXFlow() {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        captureA01Flow(suffix: "-MaxAX")
    }

    private func captureA01Flow(suffix: String) {
        navigateToActivity()
        XCTAssertTrue(waitForElement("activity-hero-readiness", timeout: 15).exists)
        capture("A01-Activity-Flow-hero\(suffix)")
        for (identifier, name) in [
            ("activity-musclemap-detail-link", "A01-Activity-Flow-map"),
            ("activity-recent-seeall", "A01-Activity-Flow-recent"),
            ("activity-section-weeklystats", "A01-Activity-Flow-weekly"),
            ("activity-section-volume", "A01-Activity-Flow-load"),
            ("activity-section-exercisemix", "A01-Activity-Flow-analysis")
        ] {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(identifier, maxSwipes: 16),
                          "\(identifier) must be reachable for the native capture")
            if suffix == "-MaxAX" {
                if identifier == "activity-section-weeklystats" {
                    XCTAssertTrue(waitForElement("activity-report-volume-value", timeout: 10).exists)
                }
                if identifier == "activity-section-volume" {
                    XCTAssertTrue(waitForElement("activity-load-timer-value", timeout: 10).exists)
                    XCTAssertTrue(waitForElement("activity-load-flame.fill-value", timeout: 10).exists)
                }
                if identifier == "activity-section-exercisemix" {
                    XCTAssertTrue(waitForElement("activity-mix-dumbbell.fill-percent", timeout: 10).exists)
                    XCTAssertTrue(waitForElement("activity-mix-figure.run-percent", timeout: 10).exists)
                }
            }
            capture(name + suffix)
        }
    }

    func testCaptureT03ChangedHero() {
        captureHero(tab: "Today", root: AXID.dashboardHeroCondition,
                    heading: "dashboard-hero-heading", title: "CONDITION", name: "T03-Today-Condition")
    }

    func testCaptureH01ChangedHero() {
        captureHero(tab: "Wellness", root: AXID.wellnessHeroScore,
                    heading: "wellness-hero-heading", title: "WELLNESS", name: "H01-Wellness-Hero")
    }

    func testCaptureL01ChangedHero() {
        captureHero(tab: "Life", root: AXID.lifeHeroProgress,
                    heading: "life-hero-heading", title: "HABITS", name: "L01-Life-Habits")
    }

    private func captureHero(tab: String, root: String, heading: String, title: String, name: String) {
        app.navigateToTab(tab)
        XCTAssertTrue(waitForElement(root, timeout: 15).exists)
        XCTAssertEqual(waitForElement(heading).label, title)
        capture(name)
    }

    private func capture(_ name: String) {
        if VisualAudit.isEnabled {
            VisualAudit.capture(name)
        } else {
            addScreenshotAttachment(named: name)
        }
    }
}
