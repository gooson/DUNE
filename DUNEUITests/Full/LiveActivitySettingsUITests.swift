@preconcurrency import XCTest

@MainActor
final class LiveActivitySettingsUITests: UITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testSportMetricsAndStylePersistIndependently() {
        navigateToSettings()

        select("settings-watch-live-activity-cardio-metric", option: "settings-watch-live-activity-cardio-distance")
        select("settings-watch-live-activity-strength-metric", option: "settings-watch-live-activity-strength-weight")
        select("settings-watch-live-activity-style", option: "settings-watch-live-activity-style-standard")
        assertSelected("settings-watch-live-activity-cardio-metric", value: "Distance")
        assertSelected("settings-watch-live-activity-strength-metric", value: "Current Set Weight")
        assertSelected("settings-watch-live-activity-style", value: "Standard")
        addScreenshotAttachment(named: "WLA02-settings-distance-weight-standard")

        // Relaunch without --ui-reset to exercise the persisted storage backend.
        var configuration = launchConfiguration
        configuration.resetState = false
        launchApp(with: configuration)
        navigateToSettings()
        assertSelected("settings-watch-live-activity-cardio-metric", value: "Distance")
        assertSelected("settings-watch-live-activity-strength-metric", value: "Current Set Weight")
        assertSelected("settings-watch-live-activity-style", value: "Standard")
        addScreenshotAttachment(named: "WLA02-settings-persisted")
    }

    private func select(_ pickerID: String, option optionID: String) {
        let picker = waitForElement(pickerID)
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(pickerID, maxSwipes: 8))
        picker.auditTap()
        let button = app.buttons[optionID].firstMatch
        let option = button.exists ? button : app.descendants(matching: .any)[optionID].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), "\(optionID) should be offered")
        option.auditTap()
    }

    private func assertSelected(_ pickerID: String, value expectedValue: String) {
        let picker = waitForElement(pickerID)
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(pickerID, maxSwipes: 8))
        let accessibleText = "\(picker.label) \(picker.value ?? "")"
        let localizedValues = [
            "Distance": ["Distance", "거리", "距離"],
            "Current Set Weight": ["Current Set Weight", "현재 세트 중량", "現在のセット重量"],
            "Standard": ["Standard", "기본", "標準"]
        ][expectedValue] ?? [expectedValue]
        XCTAssertTrue(localizedValues.contains(where: accessibleText.contains),
                      "\(pickerID) should retain \(expectedValue): \(accessibleText)")
    }
}
