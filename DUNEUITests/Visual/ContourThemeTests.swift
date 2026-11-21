import XCTest

@MainActor
final class ContourThemeTests: SeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-test-theme", "contourAtlas", "--ui-test-style", "light", "-morningBriefingDisabled", "YES"]
    }

    func testContourLightAndDarkScreens() {
        capture("Contour Today Light")
        openSettings()
        let contour = themeButton("contourAtlas")
        XCTAssertTrue(contour.isSelected)
        capture("Contour Settings Light")

        app.terminate()
        app.launchArguments = [
            "--uitesting", "--ui-reset", "--seed-mock",
            "--ui-test-theme", "contourAtlas", "--ui-test-style", "dark",
            "-morningBriefingDisabled", "YES"
        ]
        app.launch()
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        capture("Contour Today Dark")
        openSettings()
        XCTAssertTrue(themeButton("contourAtlas").isSelected)
        capture("Contour Settings Dark")
    }

    func testThemeSwitchPersistsAcrossLaunch() {
        openSettings()
        let desert = themeButton("desertWarm")
        desert.tap()
        let applyDesert = app.descendants(matching: .any)[AXID.settingsThemeApply].firstMatch
        XCTAssertTrue(applyDesert.waitForExistence(timeout: 5))
        applyDesert.auditTap()
        XCTAssertTrue(desert.isSelected)

        let contour = themeButton("contourAtlas")
        contour.tap()
        let applyTheme = app.descendants(matching: .any)[AXID.settingsThemeApply].firstMatch
        XCTAssertTrue(applyTheme.waitForExistence(timeout: 5))
        applyTheme.auditTap()
        XCTAssertTrue(contour.isSelected)

        app.terminate()
        // No reset or theme override: verify the user's persisted selection.
        app.launchArguments = ["--uitesting", "--ui-test-style", "light", "-morningBriefingDisabled", "YES"]
        app.launch()
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        openSettings()
        XCTAssertTrue(themeButton("contourAtlas").isSelected)
    }

    func testContourRemainsInteractiveAfterBackgroundResume() {
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        XCUIDevice.shared.press(.home)
        let backgrounded = NSPredicate { _, _ in
            MainActor.assumeIsolated {
                self.app.state == .runningBackground || self.app.state == .runningBackgroundSuspended
            }
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: backgrounded, object: nil)], timeout: 10),
            .completed,
            "Contour theme app should enter the background"
        )

        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        capture("Contour Today Resumed")

        navigateToActivity()
        XCTAssertTrue(app.navigationBars["Activity"].waitForExistence(timeout: 5))
        navigateToDashboard()
        openSettings()
        XCTAssertTrue(themeButton("contourAtlas").isSelected)
    }

    private func themeButton(
        _ rawValue: String,
        direction: ScrollDirection = .up
    ) -> XCUIElement {
        let identifier = "settings-theme-\(rawValue)"
        let gallery = app.scrollViews[AXID.settingsThemeGallery].firstMatch
        XCTAssertTrue(app.revealFullyVisible(identifier, in: gallery, maxMoves: 20))
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        return button
    }

    private func openSettings() {
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
        openSettingsCategory(AXID.settingsSectionAppearance)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
