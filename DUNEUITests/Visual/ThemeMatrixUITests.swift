import XCTest

/// Captures the four primary scenes for each existing theme in both appearances.
@MainActor
final class ThemeMatrixUITests: SeededUITestBaseCase {
    func testDesertWarmMatrix() {
        captureTheme("desertWarm", named: "Desert")

        navigateToWellness()
        let sleepDetail = app.buttons["wellness-hero-sleep"].firstMatch
        XCTAssertTrue(sleepDetail.waitForExistence(timeout: 10), "Desert sleep detail action should load")
        sleepDetail.tap()
        let sleepQuality = app.descendants(matching: .any)["sleep-section-quality"].firstMatch
        XCTAssertTrue(sleepQuality.waitForExistence(timeout: 10), "Sleep action should open sleep metric details")
    }

    func testDesertHeroRingsByInitialTab() {
        let roots: [(tab: String, argument: String, hero: String, ring: String, action: String)] = [
            ("Today", "today", AXID.dashboardHeroCondition, "dashboard-hero-ring", AXID.dashboardHeroCondition),
            ("Activity", "train", AXID.activityHeroReadiness, "activity-hero-ring", AXID.activityToolbarAdd),
            ("Wellness", "wellness", AXID.wellnessHeroScore, "wellness-hero-ring", "wellness-hero-sleep"),
            ("Life", "life", AXID.lifeHeroProgress, "life-hero-ring", "life-hero-checklist-button")
        ]

        for style in ["Light", "Dark"] {
            var todayRingSize: CGSize?
            for root in roots {
                var configuration = launchConfiguration
                configuration.initialTabSelectionArgument = root.argument
                configuration.additionalArguments += [
                    "--ui-test-theme", "desertWarm",
                    "--ui-test-style", style.lowercased(),
                    "-morningBriefingDisabled", "YES"
                ]
                launchApp(with: configuration)

                let combination = "Desert \(style) \(root.tab)"
                XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15), "\(combination): seeded root should load")
                let hero = app.descendants(matching: .any)[root.hero].firstMatch
                XCTAssertTrue(hero.waitForExistence(timeout: 10), "\(combination): hero should load")
                assertRing(root.ring, combination: combination)
                assertAction(root.action, combination: combination)
                if root.argument == "today" {
                    XCTAssertFalse(app.buttons["dashboard-primary-activity"].exists,
                                   "\(combination): Today hero should have no cross-tab action")
                }

                let ring = app.descendants(matching: .any)[root.ring].firstMatch
                if root.argument == "today" {
                    todayRingSize = ring.frame.size
                }
                // AX includes the stroke outside the 124pt layout circle.
                XCTAssertEqual(ring.frame.width, todayRingSize?.width ?? 0, accuracy: 1,
                               "\(combination): ring should use Today geometry")
                XCTAssertEqual(ring.frame.height, ring.frame.width, accuracy: 1,
                               "\(combination): ring should remain circular")
                XCTAssertTrue(app.windows.firstMatch.frame.contains(ring.frame), "\(combination): whole ring should fit on screen")
                XCTAssertTrue(app.descendants(matching: .any)[root.action].firstMatch.isHittable,
                              "\(combination): hero action should be reachable")
                if root.argument == "wellness" {
                    let narrative = app.descendants(matching: .any)["wellness-hero-narrative"].firstMatch
                    XCTAssertTrue(narrative.waitForExistence(timeout: 10))
                    XCTAssertLessThanOrEqual(narrative.frame.maxX, hero.frame.maxX + 1)
                }
                VisualAudit.capture("hero ring \(combination)")
                if !VisualAudit.isEnabled {
                    addScreenshotAttachment(named: combination)
                }
            }
        }
    }

    func testDesertTodayToolbarFitsAtBothAppearances() {
        for style in ["Light", "Dark"] {
            var configuration = launchConfiguration
            configuration.initialTabSelectionArgument = "today"
            configuration.additionalArguments += [
                "--ui-test-theme", "desertWarm",
                "--ui-test-style", style.lowercased(),
                "-morningBriefingDisabled", "YES"
            ]
            launchApp(with: configuration)

            let window = app.windows.firstMatch.frame
            let bell = app.buttons[AXID.dashboardToolbarNotifications].firstMatch
            let settings = app.buttons[AXID.dashboardToolbarSettings].firstMatch
            let isDuoViewport = abs(window.width - 466) < 1 || abs(window.width - 951) < 1
            for action in [bell, settings] {
                XCTAssertTrue(action.waitForExistence(timeout: 10), "Desert \(style): \(action.identifier) should appear")
                if isDuoViewport {
                    // The native Duo rail gives its 36pt AX child a 48pt host target.
                    XCTAssertGreaterThanOrEqual(action.frame.height, 36,
                                                "Desert \(style): native rail action should retain its host target")
                } else {
                    XCTAssertGreaterThanOrEqual(action.frame.width, 44,
                                                "Desert \(style): \(action.identifier) needs a 44pt target")
                    XCTAssertGreaterThanOrEqual(action.frame.height, 44,
                                                "Desert \(style): \(action.identifier) needs a 44pt target")
                }
                XCTAssertTrue(window.contains(action.frame), "Desert \(style): \(action.identifier) should fit the window")
            }
            let group = bell.frame.union(settings.frame)
            XCTAssertLessThan(abs(bell.frame.midY - settings.frame.midY), 2,
                              "Desert \(style): bell and settings should share a toolbar row")
            XCTAssertLessThanOrEqual(group.height, 64, "Desert \(style): toolbar actions must not span a tall glass area")
            XCTAssertLessThanOrEqual(group.width, 160, "Desert \(style): toolbar actions should form a compact group")
            XCTAssertLessThan(group.maxY, window.minY + window.height * 0.4,
                              "Desert \(style): toolbar group should remain in the upper portion of the viewport")
            VisualAudit.capture("Today toolbar Desert \(style)")
            if !VisualAudit.isEnabled { addScreenshotAttachment(named: "Today toolbar Desert \(style)") }
        }
    }

    func testDesertWellnessRingLayout() {
        for style in ["Light", "Dark"] {
            app.terminate()
            app.launchArguments = launchConfiguration.launchArguments + [
                "--ui-test-theme", "desertWarm",
                "--ui-test-style", style.lowercased(),
                "-morningBriefingDisabled", "YES"
            ]
            app.launch()
            navigateToWellness()

            let hero = app.descendants(matching: .any)["wellness-hero-score"].firstMatch
            let narrative = app.descendants(matching: .any)["wellness-hero-narrative"].firstMatch
            XCTAssertTrue(hero.waitForExistence(timeout: 10))
            XCTAssertTrue(narrative.waitForExistence(timeout: 10))
            XCTAssertLessThanOrEqual(narrative.frame.maxX, hero.frame.maxX + 1)
            addScreenshotAttachment(named: "Desert \(style) Wellness Ring Layout")
        }
    }

    func testIPadWellnessSleepSummaryFitsAtDefaultAndAccessibilityTextSizes() throws {
        guard app.isIPadLayout else { throw XCTSkip("Regular-width Wellness layout requires iPad") }

        for category in [nil, "UICTContentSizeCategoryAccessibilityXXXL"] {
            var configuration = launchConfiguration
            configuration.additionalArguments += [
                "--ui-test-theme", "desertWarm",
                "-morningBriefingDisabled", "YES"
            ]
            if let category {
                configuration.additionalArguments += ["-UIPreferredContentSizeCategoryName", category]
            }
            launchApp(with: configuration)
            navigateToWellness()

            let scoreLink = app.buttons[AXID.wellnessHeroScore].firstMatch
            let sleepLink = app.buttons["wellness-hero-sleep"].firstMatch
            let narrative = app.descendants(matching: .any)["wellness-hero-narrative"].firstMatch
            let latest = app.descendants(matching: .any)["wellness-sleep-latest"].firstMatch
            let average = app.descendants(matching: .any)["wellness-sleep-average"].firstMatch
            let state = category == nil ? "Default" : "Accessibility XXXL"

            XCTAssertTrue(scoreLink.waitForExistence(timeout: 10), "\(state): Wellness score link should load")
            XCTAssertTrue(sleepLink.waitForExistence(timeout: 5), "\(state): sleep link should load")
            XCTAssertTrue(narrative.waitForExistence(timeout: 5), "\(state): narrative should load")
            XCTAssertTrue(latest.waitForExistence(timeout: 5), "\(state): latest sleep should load")
            XCTAssertTrue(average.waitForExistence(timeout: 5), "\(state): sleep average should load")

            let scoreBounds = scoreLink.frame.insetBy(dx: -1, dy: -1)
            let sleepBounds = sleepLink.frame.insetBy(dx: -1, dy: -1)
            XCTAssertTrue(scoreBounds.contains(narrative.frame), "\(state): narrative should fit inside the score link")
            for item in [latest, average] {
                XCTAssertTrue(sleepBounds.contains(item.frame), "\(state): \(item.identifier) should fit inside the sleep link")
            }
            XCTAssertGreaterThanOrEqual(average.frame.minY, latest.frame.maxY - 1,
                                        "\(state): average should follow the latest sleep duration")
            if category == nil {
                XCTAssertGreaterThanOrEqual(latest.frame.minX, narrative.frame.maxX - 1,
                                            "Regular-width layout should place sleep beside the narrative")
            } else {
                XCTAssertGreaterThanOrEqual(latest.frame.minY, narrative.frame.maxY - 1,
                                            "Accessibility text should stack sleep below the narrative")
            }
            addScreenshotAttachment(named: "iPad Wellness sleep summary \(state)")
        }
    }

    func testDesertFourTabHeroesAtMaximumAccessibilityTextSize() {
        app.terminate()
        app.launchArguments = launchConfiguration.launchArguments + [
            "--ui-test-theme", "desertWarm",
            "--ui-test-style", "dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-morningBriefingDisabled", "YES"
        ]
        app.launch()

        let roots: [(tab: String, navigate: () -> Void, ring: String)] = [
            ("Today", navigateToDashboard, "dashboard-hero-ring"),
            ("Activity", navigateToActivity, "activity-hero-ring"),
            ("Wellness", navigateToWellness, "wellness-hero-ring"),
            ("Life", navigateToLife, "life-hero-ring")
        ]

        for root in roots {
            root.navigate()
            let ring = app.descendants(matching: .any)[root.ring].firstMatch
            XCTAssertTrue(ring.waitForExistence(timeout: 10), "\(root.tab) ring should remain visible at the largest text size")
            XCTAssertTrue(app.windows.firstMatch.frame.contains(ring.frame),
                          "\(root.tab) ring should fit the window at the largest text size")
            addScreenshotAttachment(named: "Desert Accessibility XXXL \(root.tab)")
        }
    }

    func testOceanCoolMatrix() {
        captureTheme("oceanCool", named: "Ocean")
    }

    func testForestGreenMatrix() {
        captureTheme("forestGreen", named: "Forest")
    }

    func testSakuraCalmMatrix() {
        captureTheme("sakuraCalm", named: "Sakura")
    }

    func testArcticDawnMatrix() {
        captureTheme("arcticDawn", named: "Arctic")
    }

    func testSolarPopMatrix() {
        captureTheme("solarPop", named: "Solar")
    }

    func testContourAtlasMatrix() {
        captureTheme("contourAtlas", named: "Contour")
    }

    private func captureTheme(_ rawValue: String, named themeName: String) {
        for style in ["Light", "Dark"] {
            app.terminate()
            app.launchArguments = launchConfiguration.launchArguments + [
                "--ui-test-theme", rawValue,
                "--ui-test-style", style.lowercased(),
                "-morningBriefingDisabled", "YES"
            ]
            app.launch()

            let combination = "\(themeName) \(style)"
            XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15), "\(combination): primary navigation should load")
            captureRoots(for: combination)
        }
    }

    private func captureRoots(for combination: String) {
        navigateToDashboard()
        captureRoot(AXID.dashboardHeroCondition, tab: "Today", combination: combination)
        assertRing("dashboard-hero-ring", combination: combination)
        assertAction(AXID.dashboardHeroCondition, combination: combination)
        XCTAssertFalse(app.buttons["dashboard-primary-activity"].exists,
                       "\(combination): Today hero should have no cross-tab action")

        navigateToActivity()
        captureRoot(AXID.activityHeroReadiness, tab: "Activity", combination: combination)
        assertRing("activity-hero-ring", combination: combination)
        assertAction(AXID.activityToolbarAdd, combination: combination)

        navigateToWellness()
        captureRoot(AXID.wellnessHeroScore, tab: "Wellness", combination: combination)
        assertRing("wellness-hero-ring", combination: combination)
        assertAction("wellness-hero-sleep", combination: combination)

        navigateToLife()
        captureRoot(AXID.lifeHeroProgress, tab: "Life", combination: combination)
        assertRing("life-hero-ring", combination: combination)
        assertAction("life-hero-checklist-button", combination: combination)
    }

    private func captureRoot(_ identifier: String, tab: String, combination: String) {
        let root = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 10), "\(combination) \(tab): \(identifier) should load")
        addScreenshotAttachment(named: "\(combination) \(tab)")
    }

    private func assertAction(_ identifier: String, combination: String) {
        let action = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 10), "\(combination): \(identifier) should load")
    }

    private func assertRing(_ identifier: String, combination: String) {
        let ring = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 10), "\(combination): \(identifier) should show the tab score ring")
    }
}
