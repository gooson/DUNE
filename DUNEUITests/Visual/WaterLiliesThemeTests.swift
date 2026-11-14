@preconcurrency import XCTest
import UIKit

@MainActor
final class WaterLiliesThemeTests: SeededUITestBaseCase {
    private var motionSettings: XCUIApplication?
    private var originalMotionSetting: Bool?

    override func tearDownWithError() throws {
        if let settings = motionSettings, let original = originalMotionSetting {
            // XCTest can abort an assertion without unwinding a Swift defer.
            // Restore the observed switch in the framework's teardown instead.
            let previous = continueAfterFailure
            continueAfterFailure = true
            settings.activate()
            let toggle = settings.switches["REDUCE_MOTION"].firstMatch
            if toggle.waitForExistence(timeout: 5), reduceMotionSwitchIsOn(toggle) != original {
                tapMotionControl(toggle)
            }
            XCTAssertEqual(reduceMotionSwitchIsOn(toggle), Optional(original))
            attachReduceMotionReadback("restored", settingsSwitch: toggle)
            app?.activate()
            continueAfterFailure = previous
        }
        motionSettings = nil
        originalMotionSetting = nil
        try super.tearDownWithError()
    }

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

    func testSupportedLanguageRootNavigation() {
        for (language, locale) in [("en", "en_US"), ("ko", "ko_KR"), ("ja", "ja_JP")] {
            var configuration = launchConfiguration
            configuration.additionalArguments += [
                "-AppleLanguages", "(\(language))", "-AppleLocale", locale
            ]
            launchApp(with: configuration)
            XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15), "\(language): primary navigation")

            let roots: [(String, () -> Void, String)] = [
                ("Today", navigateToDashboard, AXID.dashboardHeroCondition),
                ("Activity", navigateToActivity, AXID.activityHeroReadiness),
                ("Wellness", navigateToWellness, AXID.wellnessHeroScore),
                ("Life", navigateToLife, AXID.lifeHeroProgress)
            ]
            for (tab, navigate, identifier) in roots {
                navigate()
                let hero = app.descendants(matching: .any)[identifier].firstMatch
                XCTAssertTrue(hero.waitForExistence(timeout: 10), "\(language) \(tab): root should load")
                XCTAssertTrue(hero.frame.intersects(app.windows.firstMatch.frame),
                              "\(language) \(tab): root should be on screen")
                captureRootEvidence("Water Lilies \(language) \(tab)")
            }
        }
    }

    func testSystemReduceMotionPreservesConditionDetailState() throws {
        // The design capture plan may disable app animations. This selector
        // needs the real system preference, so relaunch without that argument.
        app.terminate()
        app.launchArguments = launchConfiguration.launchArguments.filter {
            $0 != "--ui-disable-animations"
        } + ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        navigateToDashboard()

        let hero = app.buttons[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        hero.tap()
        let detail = app.scrollViews[AXID.conditionScoreDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10))

        // A selected chart period exercises state owned by the detail route.
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(
            "condition-period-picker", maxSwipes: 6, timeoutPerCheck: 0.2
        ))
        let week = app.segmentedControls["condition-period-picker"].buttons["W"].firstMatch
        XCTAssertTrue(week.waitForExistence(timeout: 5))
        week.tap()
        XCTAssertTrue(waitForSelected(week), "Week should be selected before backgrounding")
        captureRootEvidence("Water Lilies condition detail before system Reduce Motion")

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        settings.launch()
        guard let reduceMotionSwitch = openReduceMotionSwitch(in: settings) else {
            throw XCTSkip("English Settings > Accessibility > Motion controls unavailable")
        }

        let original = UIAccessibility.isReduceMotionEnabled
        motionSettings = settings
        originalMotionSetting = original
        attachReduceMotionReadback("original", settingsSwitch: reduceMotionSwitch)
        XCTAssertEqual(reduceMotionSwitchIsOn(reduceMotionSwitch), Optional(original),
                       "Settings and UIKit should agree before changing the preference")
        if !original {
            // This OS exposes the whole Settings row as the Switch. Its center
            // tap left the thumb off in the original native failure capture.
            tapMotionControl(reduceMotionSwitch)
            attachReduceMotionReadback("after native control tap", settingsSwitch: reduceMotionSwitch)
            XCTAssertEqual(reduceMotionSwitchIsOn(reduceMotionSwitch), Optional(true))
            XCTAssertTrue(waitForReduceMotion(true),
                          "UIKit must report the actual system Reduce Motion preference")
        }
        XCTAssertTrue(UIAccessibility.isReduceMotionEnabled)
        XCTAssertEqual(reduceMotionSwitchIsOn(reduceMotionSwitch), Optional(true),
                       "Settings switch value must read back as 1 when Reduce Motion is enabled")
        attachReduceMotionReadback("enabled", settingsSwitch: reduceMotionSwitch)
        let settingsScreenshot = XCTAttachment(screenshot: settings.screenshot())
        settingsScreenshot.name = "Water Lilies system Reduce Motion Settings enabled"
        settingsScreenshot.lifetime = .keepAlways
        add(settingsScreenshot)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(detail.waitForExistence(timeout: 10),
                      "The detail route must survive the Settings round trip")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(
            "condition-period-picker", maxSwipes: 6, timeoutPerCheck: 0.2
        ))
        XCTAssertTrue(week.isSelected, "The selected chart period must survive scene inactivity")
        captureRootEvidence("Water Lilies condition detail with system Reduce Motion")
    }

    func testWaterLiliesRemainsOnDetailAfterBackgroundResume() {
        navigateToDashboard()
        let hero = app.buttons[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        hero.tap()
        let detail = app.scrollViews[AXID.conditionScoreDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        captureRootEvidence("Water Lilies condition detail before background")

        XCUIDevice.shared.press(.home)
        let backgrounded = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                MainActor.assumeIsolated {
                    self.app.state == .runningBackground
                        || self.app.state == .runningBackgroundSuspended
                }
            },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [backgrounded], timeout: 10), .completed)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(detail.waitForExistence(timeout: 10),
                      "The same condition detail route should remain open")
        XCTAssertTrue(detail.isHittable, "The resumed detail should accept input")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(
            "condition-period-picker", maxSwipes: 6, timeoutPerCheck: 0.2
        ))
        captureRootEvidence("Water Lilies condition detail resumed")
    }

    private func tapMotionControl(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    private func openReduceMotionSwitch(in settings: XCUIApplication) -> XCUIElement? {
        for title in ["Accessibility", "Motion"] {
            guard settings.scrollToHittableElementIfNeeded(
                title, maxSwipes: 6, timeoutPerCheck: 0.2
            ) else { return nil }
            let row = settings.staticTexts[title].firstMatch
            guard row.waitForExistence(timeout: 5) else { return nil }
            row.tap()
        }
        let toggle = settings.switches["Reduce Motion"].firstMatch
        return toggle.waitForExistence(timeout: 5) && toggle.isHittable ? toggle : nil
    }

    private func reduceMotionSwitchIsOn(_ toggle: XCUIElement) -> Bool? {
        if let value = toggle.value as? String {
            if value == "1" { return true }
            if value == "0" { return false }
        }
        if let value = toggle.value as? NSNumber {
            return value.intValue == 1
        }
        return nil
    }

    private func attachReduceMotionReadback(
        _ stage: String,
        settingsSwitch: XCUIElement
    ) {
        let attachment = XCTAttachment(string: """
            Stage: \(stage)
            UIKit UIAccessibility.isReduceMotionEnabled: \(UIAccessibility.isReduceMotionEnabled)
            Settings switch.value: \(String(describing: settingsSwitch.value))
            Settings switch isOn: \(String(describing: reduceMotionSwitchIsOn(settingsSwitch)))
            """)
        attachment.name = "Water Lilies system Reduce Motion \(stage) readback"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForReduceMotion(_ enabled: Bool) -> Bool {
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                MainActor.assumeIsolated {
                    UIAccessibility.isReduceMotionEnabled == enabled
                }
            },
            object: nil
        )
        return XCTWaiter.wait(for: [changed], timeout: 5) == .completed
    }

    private func waitForSelected(_ element: XCUIElement) -> Bool {
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == true"), object: element
        )
        return XCTWaiter.wait(for: [selected], timeout: 5) == .completed
    }

    private func assertAndCaptureTabRoots(style: String) {
        navigateToDashboard()
        XCTAssertTrue(waitForElement(AXID.dashboardHeroCondition, timeout: 10).exists)
        XCTAssertTrue(waitForElement("dashboard-hero-ring", timeout: 10).exists)
        XCTAssertTrue(app.buttons[AXID.dashboardHeroCondition].firstMatch.exists)
        XCTAssertFalse(app.buttons["dashboard-primary-activity"].exists,
                       "Today hero should not expose a cross-tab Activity action")
        captureRootEvidence("Water Lilies Today \(style)")

        navigateToActivity()
        XCTAssertTrue(waitForElement(AXID.activityHeroReadiness, timeout: 10).exists)
        XCTAssertTrue(waitForElement("activity-hero-ring", timeout: 10).exists)
        XCTAssertTrue(waitForElement(AXID.activityToolbarAdd, timeout: 10).exists)
        captureRootEvidence("Water Lilies Activity \(style)")

        navigateToWellness()
        XCTAssertTrue(waitForElement(AXID.wellnessHeroScore, timeout: 10).exists)
        XCTAssertTrue(waitForElement("wellness-hero-ring", timeout: 10).exists)
        XCTAssertTrue(waitForElement("wellness-hero-sleep", timeout: 10).exists)
        captureRootEvidence("Water Lilies Wellness \(style)")

        navigateToLife()
        XCTAssertTrue(waitForElement(AXID.lifeHeroProgress, timeout: 10).exists)
        XCTAssertTrue(waitForElement("life-hero-ring", timeout: 10).exists)
        XCTAssertFalse(app.buttons["life-hero-checklist-button"].exists)
        captureRootEvidence("Water Lilies Life \(style)")
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.lifeSectionHabits, maxSwipes: 6))

        navigateToDashboard()
        XCTAssertTrue(waitForElement(AXID.dashboardHeroCondition, timeout: 10).exists)
    }

    private func captureRootEvidence(_ name: String) {
        VisualAudit.capture(name)
        if !VisualAudit.isEnabled { addScreenshotAttachment(named: name) }
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
