@preconcurrency import XCTest

/// Source-backed HealthKit simulator-provider rows, valid on original and redesigned A07.
@MainActor
final class ExerciseTypeHealthKitVariantUITests: ActivityExerciseSeededUITestBaseCase {
    func testExistingHealthKitTypesOpenWeekDetailAndCapture() throws {
        let activity = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(activity.waitForExistence(timeout: 15), "Seeded Activity root should load")
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.activitySectionVolume, maxSwipes: 12),
            "Training Volume entry should be reachable"
        )
        app.descendants(matching: .any)[AXID.activitySectionVolume].firstMatch.tap()

        let volume = app.descendants(matching: .any)[AXID.activityTrainingVolumeDetailScreen].firstMatch
        XCTAssertTrue(volume.waitForExistence(timeout: 10), "Training Volume detail should open")
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.activityTrainingVolumeTypeList, maxSwipes: 10),
            "Exercise type list should load"
        )

        // These exact raw keys come from the existing SimulatorAdvancedMockDataProvider.
        for typeKey in ["running", "cycling", "stairStepper", "traditionalStrengthTraining"] {
            let rowID = AXID.activityTrainingVolumeRow(typeKey)
            let reachable = app.scrollToHittableElementIfNeeded(rowID, maxSwipes: 12)
                || app.scrollToHittableElementIfNeeded(rowID, maxSwipes: 12, direction: .down)
            XCTAssertTrue(reachable, "Existing provider row \(typeKey) should be reachable")
            let row = app.descendants(matching: .any)[rowID].firstMatch
            XCTAssertTrue(row.exists && row.isHittable)
            row.tap()

            let detail = app.descendants(matching: .any)[AXID.activityExerciseTypeDetailScreen].firstMatch
            let period = app.descendants(matching: .any)[AXID.activityExerciseTypePeriodPicker].firstMatch
            let trend = app.descendants(matching: .any)[AXID.activityExerciseTypeTrendChart].firstMatch
            let sessions = app.descendants(matching: .any)[AXID.activityExerciseTypeRecentSessions].firstMatch
            XCTAssertTrue(detail.waitForExistence(timeout: 10), "\(typeKey) detail should open")
            XCTAssertTrue(period.waitForExistence(timeout: 10), "\(typeKey) should retain Week period control")
            XCTAssertTrue(trend.waitForExistence(timeout: 15), "\(typeKey) trend should finish loading")
            XCTAssertTrue(sessions.waitForExistence(timeout: 10),
                          "\(typeKey) should show its existing provider session")
            addScreenshotAttachment(named: "Exercise type \(typeKey) Week loaded")
            VisualAudit.capture("Exercise type \(typeKey) Week loaded")

            // Duo exposes the system rail Back outside navigationBars.
            let railBack = app.buttons["BackButton"].firstMatch
            if railBack.exists && railBack.isHittable {
                railBack.tap()
            } else {
                let back = app.navigationBars.buttons.element(boundBy: 0)
                XCTAssertTrue(back.waitForExistence(timeout: 5), "Native Back should exist")
                back.tap()
            }
            XCTAssertTrue(volume.waitForExistence(timeout: 10),
                          "Back from \(typeKey) should return to Training Volume")
        }
    }
}
