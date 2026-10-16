import XCTest

@MainActor
final class WatchLiveHeartRateZonesUITests: WatchUITestBaseCase {
    override var uiScenario: LaunchScenario? { .responsiveLayout }
    override var additionalLaunchArguments: [String] { ["--ui-watch-six-zones"] }

    func testSixZoneWorkoutUsesLiveHealthKitConfiguration() {
        openAllExercises()
        guard let running = findQuickStartExercise(
            identifier: "watch-quickstart-exercise-running",
            maxSwipes: 8
        ) else {
            XCTFail("Running quick start should be reachable")
            return
        }
        running.tap()
        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewScreen, timeout: 5))
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton, timeout: 5))
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
}
