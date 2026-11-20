import XCTest

@MainActor
final class WatchLiveHeartRateZonesUITests: WatchUITestBaseCase {
    override var uiScenario: LaunchScenario? { .responsiveLayout }
    override var additionalLaunchArguments: [String] {
        ["--ui-watch-six-zones", "--ui-watch-direct-running",
         "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testSixZoneWorkoutUsesLiveHealthKitConfiguration() {
        XCTAssertTrue(elementExists(WatchAXID.sessionPagingRoot, timeout: 10))

        XCTAssertTrue(elementExists("watch-running-distance-metrics", timeout: 5))
        app.swipeLeft()
        let mainMetrics = app.descendants(matching: .any)["watch-cardio-main-metrics"].firstMatch
        XCTAssertTrue(mainMetrics.waitForExistence(timeout: 5) && mainMetrics.isHittable)
        captureDesignState("C01")
        navigateToHeartRatePage()
        let zoneBar = app.descendants(matching: .any)["watch-live-heart-rate-zones"].firstMatch
        XCTAssertTrue(zoneBar.waitForExistence(timeout: 5))
        XCTAssertEqual(zoneBar.value as? String, "Zone 3 of 6", "The bar should expose the current zone and total")
        let activeZone = app.staticTexts["watch-live-heart-rate-zone-label"].firstMatch
        XCTAssertTrue(activeZone.waitForExistence(timeout: 5))
        XCTAssertTrue(activeZone.label.contains("3"), "The current HealthKit zone should be visible")
        captureDesignState("C03")
        addScreenshotAttachment(named: defaultArtifactName(suffix: "six-heart-rate-zones"))
    }

    func testFirstHealthKitZoneDisplaysAsZoneOne() {
        relaunchApp(withAdditionalArguments: ["--ui-watch-first-zone"])
        XCTAssertTrue(elementExists(WatchAXID.sessionPagingRoot, timeout: 10))

        navigateToHeartRatePage()
        let zone = app.staticTexts["watch-live-heart-rate-zone-label"].firstMatch
        XCTAssertTrue(zone.waitForExistence(timeout: 5))
        XCTAssertTrue(zone.label.contains("1"), "HealthKit index zero should be shown as Zone 1")
        XCTAssertTrue(elementExists("watch-cardio-hr-zone", timeout: 5))
        captureDesignState("C03")
    }

    func testMissingHeartRateShowsNoActiveZone() {
        relaunchApp(withAdditionalArguments: ["--ui-watch-no-heart-rate"])
        XCTAssertTrue(elementExists(WatchAXID.sessionPagingRoot, timeout: 10))
        navigateToHeartRatePage()
        let zones = app.descendants(matching: .any)["watch-live-heart-rate-zones"].firstMatch
        XCTAssertTrue(zones.waitForExistence(timeout: 5))
        XCTAssertEqual(zones.value as? String, "No heart rate")
        XCTAssertFalse(app.staticTexts["watch-live-heart-rate-zone-label"].firstMatch.exists)
    }

    func testKilometerMilestoneAppearsOnCurrentPage() {
        relaunchApp(withAdditionalArguments: ["--ui-watch-kilometer-milestone"])
        XCTAssertTrue(elementExists("watch-cardio-main-metrics", timeout: 10))
        XCTAssertTrue(app.staticTexts["0.99"].waitForExistence(timeout: 5))
        navigateToHeartRatePage()
        XCTAssertTrue(elementExists("watch-cardio-hr-zone", timeout: 5))
        XCTAssertTrue(app.staticTexts["watch-cardio-distance-milestone"].waitForExistence(timeout: 5))
        captureDesignState("C13")
        app.swipeRight()
        XCTAssertTrue(app.staticTexts["1.01"].waitForExistence(timeout: 5))
    }

    private func navigateToHeartRatePage() {
        let page = app.descendants(matching: .any)["watch-cardio-hr-zone"].firstMatch
        for _ in 0..<4 {
            if page.exists && page.isHittable { return }
            app.swipeLeft()
        }
        XCTAssertTrue(page.exists && page.isHittable,
                      "The live heart-rate page should be reachable within four left swipes")
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
