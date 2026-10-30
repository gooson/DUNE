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
        assertActivityRootReadinessAndFlowOrder()
    }

    private func assertActivityRootReadinessAndFlowOrder() {
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

    func testCaptureRecentWorkoutAchievements() {
        captureRecentWorkoutAchievements(maximumText: false)
    }

    func testCaptureRecentWorkoutAchievementsMaximumText() {
        captureRecentWorkoutAchievements(maximumText: true)
    }

    private func captureRecentWorkoutAchievements(maximumText: Bool) {
        var configuration = launchConfiguration
        if let style = configuration.additionalArguments.firstIndex(of: "--ui-test-style") {
            configuration.additionalArguments[style + 1] = "dark"
        }
        if let languages = configuration.additionalArguments.firstIndex(of: "-AppleLanguages") {
            configuration.additionalArguments[languages + 1] = "(en)"
        }
        if maximumText {
            configuration.additionalArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        launchApp(with: configuration)
        navigateToActivity()
        XCTAssertTrue(waitForElement("activity-hero-readiness", timeout: 15).exists)
        alignActivityCaptureHeader("activity-recent-seeall")

        // The imported run earns a distance milestone and PR together. Its
        // longer 10K label also exercises the layout used by a 5K milestone.
        let rowID = "activity-recent-workout-mock-workout-running-tempo"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(rowID, maxSwipes: 12),
                      "The seeded recent run must be visible")
        let rewardedRow = app.buttons[rowID].firstMatch
        XCTAssertTrue(rewardedRow.waitForExistence(timeout: 10))
        XCTAssertTrue(rewardedRow.label.contains("Achievement: 10K"),
                      "The recent run must expose its distance achievement")
        XCTAssertTrue(rewardedRow.label.contains("Personal record:"),
                      "The same run must expose its personal record semantics")
        let suffix = maximumText ? "maximum-text" : "default-text"
        capture("A01-recent-achievements-\(suffix)")
        captureTallCardSections(start: "activity-recent-seeall", next: "activity-section-pr",
                                name: "A01-recent-achievements-\(suffix)")
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
        // The opt-in audit preserves nineteen viewports plus their AX trees.
        // Keep this collection budget separate from the focused product checks.
        if VisualAudit.isEnabled { executionTimeAllowance = 600 }
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        captureA01Flow(suffix: "-MaxAX")
    }

    func testPersonalRecordValueAtMaximumAccessibilitySize() {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToActivity()
        alignActivityCaptureHeader("activity-section-pr")
        capture("A01-PersonalRecords-MaxAX-header")

        let records = app.buttons["activity-section-pr-content"].firstMatch
        let numeric = NSPredicate(format: "label MATCHES %@", "^[0-9][0-9.,:'\"msh]*$")
        let value = records.staticTexts.matching(numeric).firstMatch
        XCTAssertTrue(value.waitForExistence(timeout: 10), "A seeded personal record should expose its primary value")
        let viewport = usableActivityViewport()
        alignActivityPosition(at: viewport.midY - value.frame.height / 2) { value.frame.minY }
        XCTAssertTrue(usableActivityViewport().insetBy(dx: -1, dy: -1).contains(value.frame),
                      "The complete record value should fit in the usable viewport")
        capture("A01-PersonalRecords-MaxAX-value")
    }

    func testActivityMetricValuesAtMaximumAccessibilitySize() {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToActivity()
        let groups = [
            ["activity-report-volume-value"],
            ["activity-load-timer-value", "activity-load-flame.fill-value"],
            ["activity-mix-dumbbell.fill-percent", "activity-mix-figure.run-percent"]
        ]
        for identifiers in groups {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(identifiers[0], maxSwipes: 18),
                          "The metric group should remain reachable at maximum text size")
            for identifier in identifiers {
                let value = waitForElement(identifier, timeout: 10)
                XCTAssertGreaterThan(value.frame.width, 0, "\(identifier) should render a value")
                XCTAssertGreaterThan(value.frame.height, 0, "\(identifier) should render a value")
            }
        }
    }

    private func captureA01Flow(suffix: String) {
        navigateToActivity()
        XCTAssertTrue(waitForElement("activity-hero-readiness", timeout: 15).exists)
        capture("A01-Activity-Flow-hero\(suffix)")
        for (identifier, nextSection, name) in [
            ("activity-musclemap-detail-link", "activity-section-injuryrisk", "A01-Activity-Flow-map"),
            ("activity-recent-seeall", "activity-section-pr", "A01-Activity-Flow-recent"),
            ("activity-section-pr", "activity-section-weeklystats", "A01-Activity-Flow-records"),
            ("activity-section-weeklystats", "activity-section-weeklyreport", "A01-Activity-Flow-weekly"),
            ("activity-section-weeklyreport", "activity-section-consistency", "A01-Activity-Flow-report"),
            ("activity-section-volume", "activity-section-exercisemix", "A01-Activity-Flow-load"),
            ("activity-section-exercisemix", "", "A01-Activity-Flow-analysis")
        ] {
            alignActivityCaptureHeader(identifier)
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
            if !nextSection.isEmpty {
                let boundary = captureBoundary(start: identifier, next: nextSection)
                captureTallCardSections(start: identifier, next: boundary, name: name + suffix)
            }
        }
    }

    /// Align a header with the visible content area, including the navigation bar.
    /// The short measured drags can correct in either direction if scrolling coasts.
    private func alignActivityCaptureHeader(_ identifier: String) {
        let header = element(identifier)
        XCTAssertTrue(header.waitForExistence(timeout: 10),
                      "\(identifier) must exist for the native capture")
        let viewport = usableActivityViewport()
        if !header.isHittable {
            let direction: ScrollDirection = header.frame.minY < viewport.minY ? .down : .up
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(identifier, maxSwipes: 16, direction: direction),
                          "\(identifier) must be reachable for the native capture")
        }
        alignActivityPosition(at: viewport.minY + 12) { header.frame.minY }
    }

    private func captureBoundary(start: String, next: String) -> String {
        guard start == "activity-section-pr" else { return next }
        let records = element(start)
        let achievement = element(next)
        guard records.exists, achievement.exists,
              abs(records.frame.minY - achievement.frame.minY) < 40 else { return next }
        // In two-column layouts the achievement header shares the PR row;
        // the following weekly row marks the records group's lower edge.
        return "activity-section-weeklystats"
    }

    private func captureTallCardSections(start: String, next: String, name: String) {
        let first = element(start)
        let following = element(next)
        guard first.exists, following.exists else { return }
        let viewport = usableActivityViewport()
        let span = following.frame.minY - first.frame.minY
        guard span > viewport.height * 0.9 else { return }

        // Preserve one representative interior view for any card taller than
        // the usable viewport, regardless of style or text size.
        let interiorShift = min((span - viewport.height) / 2, viewport.height * 0.45)
        let interiorTop = first.frame.minY - max(0, interiorShift)
        alignActivityPosition(at: interiorTop) { first.frame.minY }
        capture(name + "-middle")

        guard span > viewport.height * 1.35 else { return }
        // The next heading near the bottom leaves the current card's legend or
        // final content visible without requiring its full height to fit.
        let direction: ScrollDirection = following.frame.minY < viewport.minY ? .down : .up
        _ = app.scrollToHittableElementIfNeeded(next, maxSwipes: 16, direction: direction)
        alignActivityPosition(at: viewport.maxY - min(72, viewport.height * 0.1)) {
            following.frame.minY
        }
        capture(name + "-end")
    }

    private func usableActivityViewport() -> CGRect {
        let scroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
        let navigationBar = app.navigationBars.firstMatch
        let top = max(viewport.minY, navigationBar.exists ? navigationBar.frame.maxY : viewport.minY)
        let tabBar = app.tabBars.firstMatch
        let bottom = tabBar.exists && tabBar.frame.minY > viewport.midY
            ? min(viewport.maxY, tabBar.frame.minY) : viewport.maxY
        return CGRect(x: viewport.minX, y: top,
                      width: viewport.width, height: max(1, bottom - top))
    }

    private func alignActivityPosition(at targetY: CGFloat, position: () -> CGFloat) {
        let viewport = usableActivityViewport()
        for _ in 0..<12 {
            let before = position()
            let delta = before - targetY
            if abs(delta) <= 10 { return }
            let distance = min(min(abs(delta), 200), viewport.height * 0.3)
            dragActivityScroll(by: delta > 0 ? distance : -distance)
            if abs(position() - before) < 2 { return }
        }
    }

    /// Positive distance moves content upward; negative distance corrects upward overshoot.
    private func dragActivityScroll(by distance: CGFloat) {
        let scroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        let fraction = distance / max(1, scroll.frame.height)
        let origin = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let destination = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6 - fraction))
        origin.press(forDuration: 0.18, thenDragTo: destination,
                     withVelocity: XCUIGestureVelocity(rawValue: 100), thenHoldForDuration: 0.5)
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

    func testCaptureDuoClosedFlowAndHeadings() throws {
        try captureDuoFlowAndHeadings(posture: "closed", suffix: "DuoClosed")
    }

    func testCaptureDuoOpenFlowAndHeadings() throws {
        try captureDuoFlowAndHeadings(posture: "openFlat", suffix: "DuoOpen")
    }

    private func captureDuoFlowAndHeadings(posture: String, suffix: String) throws {
        guard VisualAudit.isEnabled,
              ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_HOST_ONLY"] == "1",
              ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_FOLD"] == "1" else {
            throw XCTSkip("Opt-in Duo native capture only")
        }
        executionTimeAllowance = 600

        navigateToActivity()
        VisualAudit.capture("FOLD:\(posture) Activity final flow")
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15),
                      "Activity should remain available after \(posture) transition")
        assertActivityRootReadinessAndFlowOrder()
        assertDuoHeroRing("activity-hero-ring", diameter: 104)
        captureA01Flow(suffix: "-\(suffix)")

        captureHero(tab: "Today", root: AXID.dashboardHeroCondition,
                    heading: "dashboard-hero-heading", title: "CONDITION",
                    name: "T03-\(suffix)-Condition")
        assertDuoHeroRing("dashboard-hero-ring", diameter: 104)
        captureHero(tab: "Wellness", root: AXID.wellnessHeroScore,
                    heading: "wellness-hero-heading", title: "WELLNESS",
                    name: "H01-\(suffix)-Wellness")
        // The 124pt shared ring's 11pt stroke is included in its AX bounds.
        assertDuoHeroRing("wellness-hero-ring", diameter: 135)
        captureHero(tab: "Life", root: AXID.lifeHeroProgress,
                    heading: "life-hero-heading", title: "HABITS",
                    name: "L01-\(suffix)-Habits")
        assertDuoHeroRing("life-hero-ring", diameter: 135)
    }

    private func assertDuoHeroRing(_ identifier: String, diameter: CGFloat) {
        let ring = waitForElement(identifier, timeout: 10)
        XCTAssertEqual(ring.frame.width, diameter, accuracy: 1,
                       "\(identifier) should keep its tab's ring diameter")
        XCTAssertEqual(ring.frame.height, ring.frame.width, accuracy: 1,
                       "\(identifier) should remain circular")
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
