import XCTest

@MainActor
final class ContourThemeTests: SeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-test-theme", "contourAtlas", "--ui-test-style", "light"]
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
            "--ui-test-theme", "contourAtlas", "--ui-test-style", "dark"
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
        let desert = themeButton("desertWarm", direction: .down)
        desert.tap()
        XCTAssertTrue(desert.isSelected)

        let contour = themeButton("contourAtlas")
        contour.tap()
        XCTAssertTrue(contour.isSelected)
        XCTAssertFalse(desert.isSelected)

        app.terminate()
        // No reset or theme override: verify the user's persisted selection.
        app.launchArguments = ["--uitesting", "--ui-test-style", "light"]
        app.launch()
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        openSettings()
        XCTAssertTrue(themeButton("contourAtlas").isSelected)
    }

    private func themeButton(
        _ rawValue: String,
        direction: ScrollDirection = .up
    ) -> XCUIElement {
        let identifier = "settings-theme-\(rawValue)"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(identifier, maxSwipes: 16, direction: direction))
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
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
