@preconcurrency import XCTest

@MainActor
private func dismissIconConfirmation() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let alert = springboard.alerts.firstMatch
    if alert.waitForExistence(timeout: 3), alert.buttons.firstMatch.exists {
        alert.buttons.firstMatch.tap()
    }
}

@MainActor
final class AppIconSettingsUITests: SeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-test-theme", "desertWarm", "-morningBriefingDisabled", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testSelectionPersistsAndThemeUpdatesIconAndSplash() throws {
        navigateToSettings()
        openIconPicker()
        let defaultButton = app.buttons["settings-app-icon-interleave"]
        XCTAssertTrue(defaultButton.isSelected)
        let flow = app.buttons["settings-app-icon-flow"]
        flow.tap()
        dismissIconConfirmation()
        XCTAssertTrue(flow.isSelected)
        let applied = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "App icon updated"), object: flow)
        // The system icon service can finish after its confirmation is dismissed.
        XCTAssertEqual(
            XCTWaiter.wait(for: [applied], timeout: 90), .completed,
            "System icon completion status: \(String(describing: flow.value))"
        )
        reveal("launch-brand-flow-desertWarm")
        XCTAssertTrue(app.images["launch-brand-flow-desertWarm"].exists)
        reveal("settings-app-icon-palette")
        XCTAssertEqual(app.staticTexts["settings-app-icon-palette"].label, "Coral × Sand")
        addScreenshotAttachment(named: "app-icon-flow-p04")

        var configuration = launchConfiguration
        configuration.resetState = false
        launchApp(with: configuration)
        navigateToSettings()
        openIconPicker()
        XCTAssertTrue(app.buttons["settings-app-icon-flow"].isSelected)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal("settings-theme-forestGreen")
        app.buttons["settings-theme-forestGreen"].tap()
        dismissIconConfirmation()
        reveal("settings-row-app-icon", scrollingDown: false)
        app.descendants(matching: .any)["settings-row-app-icon"].firstMatch.tap()
        reveal("launch-brand-flow-forestGreen")
        XCTAssertTrue(app.images["launch-brand-flow-forestGreen"].waitForExistence(timeout: 8))
        reveal("settings-app-icon-palette")
        XCTAssertEqual(app.staticTexts["settings-app-icon-palette"].label, "Sage × Cream")
        addScreenshotAttachment(named: "app-icon-flow-forest")
    }

    private func openIconPicker() {
        reveal("settings-row-app-icon")
        let row = app.descendants(matching: .any)["settings-row-app-icon"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        addScreenshotAttachment(named: "settings-app-icon-entry")
        row.tap()
        XCTAssertTrue(app.buttons["settings-app-icon-ocean"].waitForExistence(timeout: 8))
        addScreenshotAttachment(named: "app-icon-choices")
    }

    /// Short drags keep a single row from being skipped by a page-sized swipe.
    private func reveal(_ identifier: String, scrollingDown: Bool = true) {
        let target = app.descendants(matching: .any)[identifier].firstMatch
        for _ in 0..<24 {
            let viewport = app.frame
            if target.exists && target.isHittable,
               target.frame.minY > viewport.minY + 100,
               target.frame.maxY < viewport.maxY - 80 { return }
            let startY = scrollingDown ? 0.72 : 0.42
            let endY = scrollingDown ? 0.42 : 0.72
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: startY))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: endY)))
        }
    }
}

@MainActor
final class AppIconLaunchUITests: XCTestCase {
    func testSplashUsesAllThreeSelectedDesigns() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        defer { app.terminate() }
        for (style, theme) in [("interleave", "desertWarm"), ("ocean", "oceanCool"), ("flow", "forestGreen")] {
            app.terminate()
            app.launchArguments = ["--uitesting", "--ui-reset", "--ui-test-launch-brand", "--ui-test-icon", style, "--ui-test-theme", theme, "--ui-disable-animations", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            app.launch()
            dismissIconConfirmation()
            XCTAssertTrue(app.images["launch-brand-\(style)-\(theme)"].waitForExistence(timeout: 15))
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "app-splash-\(style)-\(theme)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
