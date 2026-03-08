@preconcurrency import XCTest

@MainActor
final class ActivityMuscleMapRegressionTests: ActivityExerciseSeededUITestBaseCase {

    // MARK: - MuscleMapDetailView Tests

    func testMuscleMapDetailViewLoads() throws {
        navigateToMuscleMapDetail()

        let detailScreen = app.descendants(matching: .any)[AXID.activityMuscleMapDetailScreen].firstMatch
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10), "Muscle Map detail screen should appear")
    }

    func testMuscleMapDetailViewShowsVolumeSectionWithSeededData() throws {
        navigateToMuscleMapDetail()

        let volumeSection = app.descendants(matching: .any)[AXID.muscleMapDetailVolumeSection].firstMatch
        XCTAssertTrue(
            volumeSection.waitForExistence(timeout: 10),
            "Volume Analysis section should exist on Muscle Map detail"
        )
    }

    func testMuscleMapDetailViewShowsRecoverySectionWithSeededData() throws {
        navigateToMuscleMapDetail()

        let recoverySection = app.descendants(matching: .any)[AXID.muscleMapDetailRecoverySection].firstMatch
        XCTAssertTrue(
            recoverySection.waitForExistence(timeout: 10),
            "Recovery Status section should exist on Muscle Map detail"
        )
    }

    func testMuscleMapDetailViewNavigatesTo3D() throws {
        navigateToMuscleMapDetail()

        // Tap the muscle recovery map to trigger 3D navigation
        let detailScreen = app.descendants(matching: .any)[AXID.activityMuscleMapDetailScreen].firstMatch
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10))

        // Tap on the map area — muscle selection triggers 3D navigation
        detailScreen.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()

        let screen3D = app.descendants(matching: .any)[AXID.activityMuscleMap3DScreen].firstMatch
        XCTAssertTrue(
            screen3D.waitForExistence(timeout: 10),
            "MuscleMap3DView should appear after tapping a muscle"
        )
    }

    // MARK: - MuscleMap3DView Tests

    func testMuscleMap3DViewLoads() throws {
        navigateTo3DView()

        let screen = app.descendants(matching: .any)[AXID.activityMuscleMap3DScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "3D screen should appear")

        let summaryCard = app.descendants(matching: .any)[AXID.muscleMap3DSummaryCard].firstMatch
        XCTAssertTrue(summaryCard.exists, "Summary card should be visible")

        let modePicker = app.descendants(matching: .any)[AXID.muscleMap3DModePicker].firstMatch
        XCTAssertTrue(modePicker.exists, "Mode picker should be visible")
    }

    func testMuscleMap3DViewModePickerSwitches() throws {
        navigateTo3DView()

        let modePicker = app.descendants(matching: .any)[AXID.muscleMap3DModePicker].firstMatch
        XCTAssertTrue(modePicker.waitForExistence(timeout: 10), "Mode picker should exist")

        // The picker starts on Recovery (first case). Tap Volume segment.
        let volumeButton = modePicker.buttons["Volume"]
        if volumeButton.exists {
            volumeButton.tap()

            // Summary card should still exist after mode switch
            let summaryCard = app.descendants(matching: .any)[AXID.muscleMap3DSummaryCard].firstMatch
            XCTAssertTrue(summaryCard.exists, "Summary card should persist after mode switch")
        }
    }

    func testMuscleMap3DViewMuscleStripExists() throws {
        navigateTo3DView()

        let muscleStrip = app.descendants(matching: .any)[AXID.muscleMap3DMuscleStrip].firstMatch
        XCTAssertTrue(
            muscleStrip.waitForExistence(timeout: 10),
            "Muscle selection strip should exist in 3D view"
        )

        // Verify strip contains at least one button (muscle capsule)
        let buttons = muscleStrip.buttons
        XCTAssertGreaterThan(buttons.count, 0, "Muscle strip should contain muscle buttons")
    }

    func testMuscleMap3DViewResetButton() throws {
        navigateTo3DView()

        let resetButton = app.descendants(matching: .any)[AXID.muscleMap3DResetButton].firstMatch
        XCTAssertTrue(
            resetButton.waitForExistence(timeout: 10),
            "Reset button should exist in 3D view toolbar"
        )

        // Tap should not crash
        resetButton.tap()

        // Screen should still be present
        let screen = app.descendants(matching: .any)[AXID.activityMuscleMap3DScreen].firstMatch
        XCTAssertTrue(screen.exists, "3D screen should persist after reset")
    }

    func testMuscleMap3DViewerExists() throws {
        navigateTo3DView()

        let viewer = app.descendants(matching: .any)[AXID.muscleMap3DViewer].firstMatch
        XCTAssertTrue(
            viewer.waitForExistence(timeout: 10),
            "3D viewer (ARView container) should exist"
        )
    }

    // MARK: - Helpers

    private func navigateToMuscleMapDetail() {
        let hero = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Activity hero should exist")

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionMuscleMap, maxSwipes: 4))
        let section = app.descendants(matching: .any)[AXID.activitySectionMuscleMap].firstMatch
        XCTAssertTrue(section.waitForExistence(timeout: 5), "Muscle map section should exist")
        section.tap()

        let detailScreen = app.descendants(matching: .any)[AXID.activityMuscleMapDetailScreen].firstMatch
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10), "Muscle Map detail should appear")
    }

    private func navigateTo3DView() {
        navigateToMuscleMapDetail()

        // Tap on the muscle map area to trigger 3D navigation (muscle selection = 3D push)
        let detailScreen = app.descendants(matching: .any)[AXID.activityMuscleMapDetailScreen].firstMatch
        detailScreen.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()

        let screen3D = app.descendants(matching: .any)[AXID.activityMuscleMap3DScreen].firstMatch
        XCTAssertTrue(screen3D.waitForExistence(timeout: 10), "3D view should appear")
    }

    private func tapBackButton() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should exist")
        backButton.tap()
    }
}
