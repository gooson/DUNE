import XCTest

@MainActor
final class WaterLiliesThemeTests: SeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-test-theme", "waterLilies", "--ui-test-style", "light", "-morningBriefingDisabled", "YES"]
    }

    func testFourTabRootsInLightAndDark() {
        assertAndCaptureTabRoots(style: "Light")
        openSettings()
        XCTAssertTrue(themeButton("waterLilies").isSelected)
        addScreenshotAttachment(named: "Water Lilies Settings Light")

        app.terminate()
        var darkArguments = launchConfiguration.launchArguments
        guard let styleIndex = darkArguments.firstIndex(of: "--ui-test-style") else {
            XCTFail("The deterministic appearance argument is required")
            return
        }
        darkArguments[styleIndex + 1] = "dark"
        app.launchArguments = darkArguments
        app.launch()

        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        assertAndCaptureTabRoots(style: "Dark")
        openSettings()
        XCTAssertTrue(themeButton("waterLilies").isSelected)
        addScreenshotAttachment(named: "Water Lilies Settings Dark")
    }

    func testThemeSelectionPersistsAcrossLaunch() {
        openSettings()
        XCTAssertTrue(themeButton("waterLilies").isSelected)

        let desert = themeButton("desertWarm", direction: .down)
        desert.tap()
        XCTAssertTrue(desert.isSelected)

        let waterLilies = themeButton("waterLilies")
        waterLilies.tap()
        XCTAssertTrue(waterLilies.isSelected)

        app.terminate()
        // Omit reset and theme override so this checks the user's saved selection.
        app.launchArguments = ["--uitesting", "--ui-test-style", "light", "-morningBriefingDisabled", "YES"]
        app.launch()
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        openSettings()
        XCTAssertTrue(themeButton("waterLilies").isSelected)
    }

    private func assertAndCaptureTabRoots(style: String) {
        navigateToDashboard()
        XCTAssertTrue(waitForElement(AXID.dashboardHeroCondition, timeout: 10).exists)
        XCTAssertTrue(waitForElement("dashboard-hero-ring", timeout: 10).exists)
        XCTAssertTrue(app.buttons[AXID.dashboardHeroCondition].firstMatch.exists)
        XCTAssertFalse(app.buttons["dashboard-primary-activity"].exists,
                       "Today hero should not expose a cross-tab Activity action")
        addScreenshotAttachment(named: "Water Lilies Today \(style)")

        navigateToActivity()
        XCTAssertTrue(waitForElement(AXID.activityHeroReadiness, timeout: 10).exists)
        XCTAssertTrue(waitForElement("activity-hero-ring", timeout: 10).exists)
        XCTAssertTrue(waitForElement("activity-log-workout-button", timeout: 10).exists)
        addScreenshotAttachment(named: "Water Lilies Activity \(style)")

        navigateToWellness()
        XCTAssertTrue(waitForElement(AXID.wellnessHeroScore, timeout: 10).exists)
        XCTAssertTrue(waitForElement("wellness-hero-ring", timeout: 10).exists)
        XCTAssertTrue(waitForElement("wellness-hero-sleep", timeout: 10).exists)
        addScreenshotAttachment(named: "Water Lilies Wellness \(style)")

        navigateToLife()
        XCTAssertTrue(waitForElement(AXID.lifeHeroProgress, timeout: 10).exists)
        XCTAssertTrue(waitForElement("life-hero-ring", timeout: 10).exists)
        XCTAssertTrue(waitForElement("life-hero-checklist-button", timeout: 10).exists)
        addScreenshotAttachment(named: "Water Lilies Life \(style)")

        navigateToDashboard()
        XCTAssertTrue(waitForElement(AXID.dashboardHeroCondition, timeout: 10).exists)
    }

    private func themeButton(
        _ rawValue: String,
        direction: ScrollDirection = .up
    ) -> XCUIElement {
        let identifier = "settings-theme-\(rawValue)"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(
            identifier, maxSwipes: 8, direction: direction, timeoutPerCheck: 0.2
        ))
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        return button
    }

    private func openSettings() {
        navigateToDashboard()
        let candidates = app.buttons.matching(identifier: AXID.dashboardToolbarSettings)
        let visible = NSPredicate { _, _ in
            MainActor.assumeIsolated {
                candidates.allElementsBoundByIndex.contains { $0.isHittable }
            }
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: visible, object: nil)], timeout: 10),
            .completed
        )
        guard let button = candidates.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("A visible Settings button is required")
            return
        }
        button.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }
}
