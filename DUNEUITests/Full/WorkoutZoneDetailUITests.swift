@preconcurrency import XCTest

/// Verifies the estimated-zone fallback for an imported simulator workout.
@MainActor
final class WorkoutZoneDetailUITests: ActivityExerciseSeededUITestBaseCase {
    private enum Fixture {
        static let workoutID = "mock-workout-running-tempo"
        static let zoneSection = "healthkit-workout-zones-section"
        static let zoneSource = "healthkit-workout-zones-source"
    }

    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testImportedWorkoutShowsEstimatedHeartRateZones() throws {
        // Arrange: the seeded imported workout has heart-rate samples but no
        // HealthKit zone group, so the app must show its estimated fallback.
        navigateToActivity()
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.activityRecentSeeAll, maxSwipes: 24),
            "Recent workouts should be reachable"
        )
        app.buttons[AXID.activityRecentSeeAll].firstMatch.auditTap()
        XCTAssertTrue(waitForElement(AXID.exerciseViewScreen, timeout: 10).exists)

        // Act: open the imported workout from the full exercise list.
        let rowID = AXID.exerciseRow(Fixture.workoutID)
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(rowID, maxSwipes: 12),
            "The seeded imported workout should appear in Exercise"
        )
        app.buttons[rowID].firstMatch.auditTap()
        XCTAssertTrue(waitForElement(AXID.healthkitWorkoutDetailScreen, timeout: 10).exists)

        // Assert: the fallback labels its source and exposes several zone rows.
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(Fixture.zoneSection, maxSwipes: 12),
            "Heart-rate zones should be visible in workout detail"
        )
        let source = app.staticTexts[Fixture.zoneSource].firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 10), "Zone source should be accessible")
        XCTAssertEqual(source.label, "Estimated zones")

        for index in 1...3 {
            let zone = app.descendants(matching: .any)["healthkit-workout-zone-\(index)"].firstMatch
            XCTAssertTrue(zone.waitForExistence(timeout: 5), "Zone \(index) should be present")
            XCTAssertTrue(zone.label.contains("bpm"), "Zone \(index) should expose its heart-rate range")
        }
        addScreenshotAttachment(named: defaultArtifactName(suffix: "estimated-heart-rate-zones"))
    }
}
