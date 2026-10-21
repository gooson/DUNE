import XCTest

@MainActor
final class WatchLiveHeartRateZonesUITests: WatchUITestBaseCase {
    override var uiScenario: LaunchScenario? { .responsiveLayout }
    override var additionalLaunchArguments: [String] { ["--ui-watch-six-zones", "--ui-watch-direct-running"] }

    func testSixZoneWorkoutUsesLiveHealthKitConfiguration() {
        XCTAssertTrue(elementExists(WatchAXID.sessionPagingRoot, timeout: 10))

        app.swipeLeft()
        let zoneBar = app.descendants(matching: .any)["watch-live-heart-rate-zones"].firstMatch
        XCTAssertTrue(zoneBar.waitForExistence(timeout: 5))
        XCTAssertEqual(zoneBar.value as? String, "6", "The bar should retain all six HealthKit zones")
        let activeZone = app.staticTexts["watch-live-heart-rate-zone-label"].firstMatch
        XCTAssertTrue(activeZone.waitForExistence(timeout: 5))
        XCTAssertTrue(activeZone.label.contains("3"), "The current HealthKit zone should be visible")
        addScreenshotAttachment(named: defaultArtifactName(suffix: "six-heart-rate-zones"))
    }

    func testFirstHealthKitZoneDisplaysAsZoneOne() {
        relaunchApp(withAdditionalArguments: ["--ui-watch-first-zone"])
        XCTAssertTrue(elementExists(WatchAXID.sessionPagingRoot, timeout: 10))

        app.swipeLeft()
        let zone = app.staticTexts["watch-live-heart-rate-zone-label"].firstMatch
        XCTAssertTrue(zone.waitForExistence(timeout: 5))
        XCTAssertTrue(zone.label.contains("1"), "HealthKit index zero should be shown as Zone 1")
        XCTAssertTrue(elementExists("watch-cardio-hr-zone", timeout: 5))
        captureDesignState("C03")
    }

    func testKilometerMilestoneAppearsOnCurrentPage() {
        relaunchApp(withAdditionalArguments: ["--ui-watch-kilometer-milestone"])
        XCTAssertTrue(elementExists("watch-cardio-main-metrics", timeout: 10))
        XCTAssertTrue(app.staticTexts["0.99"].waitForExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(elementExists("watch-cardio-hr-zone", timeout: 5))
        XCTAssertTrue(app.staticTexts["watch-cardio-distance-milestone"].waitForExistence(timeout: 5))
        captureDesignState("C13")
        app.swipeRight()
        XCTAssertTrue(app.staticTexts["1.01"].waitForExistence(timeout: 5))
    }

    private func captureDesignState(_ code: String) {
        let name = "watch-design-map-\(code)"
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Keep a simulator-local copy if Xcode stalls before finalizing the result bundle.
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        XCTAssertNoThrow(try screenshot.pngRepresentation.write(to: destination))
    }
}
