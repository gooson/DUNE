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

    func testMuscleMapDetailKeeps2DSelectionWith3DEntryDisabled() throws {
        navigateToMuscleMapDetail()

        let entryLabels = ["3D Muscle Map", "3D 근육맵", "3Dマッスルマップ"]
        let open3D = app.buttons.matching(NSPredicate(format: "label IN %@", entryLabels)).firstMatch
        XCTAssertTrue(open3D.waitForExistence(timeout: 5), "The original 3D entry should remain visible")
        XCTAssertFalse(open3D.isEnabled, "A04 should disable the original 3D entry")
        addScreenshotAttachment(named: "A03 default map with disabled 3D entry")
        VisualAudit.capture("A03 default map with disabled 3D entry")

        tapFrontChestMuscle()

        let detailScreen = app.descendants(matching: .any)[AXID.activityMuscleMapDetailScreen].firstMatch
        let inlineDetail = app.descendants(matching: .any)["musclemap-detail-selected-muscle"].firstMatch
        let screen3D = app.descendants(matching: .any)[AXID.activityMuscleMap3DScreen].firstMatch
        XCTAssertTrue(detailScreen.exists, "Muscle selection should remain on the 2D detail screen")
        XCTAssertTrue(inlineDetail.waitForExistence(timeout: 5), "Selected muscle detail should appear inline")
        XCTAssertTrue(app.buttons["activity-muscle-detail-calculation"].firstMatch.waitForExistence(timeout: 5),
                      "The selected muscle should retain its calculation button accessibility ID")
        XCTAssertFalse(screen3D.exists, "Muscle selection should not open the 3D viewer")
        let primaryScroll = app.scrollViews.firstMatch
        let visibleMap = primaryScroll.frame.intersection(app.windows.firstMatch.frame)
        for _ in 0..<8 where !visibleMap.contains(open3D.frame) { primaryScroll.swipeUp() }
        XCTAssertTrue(visibleMap.contains(open3D.frame), "The disabled 3D entry should remain visible on the map")
        XCTAssertFalse(open3D.isEnabled, "Selecting a 2D muscle should not enable the 3D entry")
        addScreenshotAttachment(named: "A04 2D muscle selection and disabled 3D entry")
        VisualAudit.capture("A04 2D muscle selection and disabled 3D entry")
    }

    func testMuscleMapDetailViewNavigatesTo3D() throws {
        try navigateTo3DView()

        let screen3D = app.descendants(matching: .any)[AXID.activityMuscleMap3DScreen].firstMatch
        XCTAssertTrue(
            screen3D.waitForExistence(timeout: 10),
            "MuscleMap3DView should appear through the layout's 3D entry"
        )
    }

    // MARK: - MuscleMap3DView Tests

    func testMuscleMap3DViewLoads() throws {
        try navigateTo3DView()

        let screen = app.descendants(matching: .any)[AXID.activityMuscleMap3DScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "3D screen should appear")

        let summaryCard = app.descendants(matching: .any)[AXID.muscleMap3DSummaryCard].firstMatch
        XCTAssertTrue(summaryCard.exists, "Summary card should be visible")

        let modePicker = app.descendants(matching: .any)[AXID.muscleMap3DModePicker].firstMatch
        XCTAssertTrue(modePicker.exists, "Mode picker should be visible")
    }

    func testMuscleMap3DViewModePickerSwitches() throws {
        try navigateTo3DView()

        let modePicker = app.descendants(matching: .any)[AXID.muscleMap3DModePicker].firstMatch
        XCTAssertTrue(modePicker.waitForExistence(timeout: 10), "Mode picker should exist")

        // The picker starts on Recovery (first case). Tap Volume segment.
        let volumeButton = modePicker.buttons.element(boundBy: 1)
        XCTAssertTrue(volumeButton.waitForExistence(timeout: 5), "Volume segment should be present in mode picker")
        volumeButton.tap()

        // Summary card should still exist after mode switch
        let summaryCard = app.descendants(matching: .any)[AXID.muscleMap3DSummaryCard].firstMatch
        XCTAssertTrue(summaryCard.exists, "Summary card should persist after mode switch")
    }

    func testMuscleMap3DViewMuscleStripExists() throws {
        try navigateTo3DView()

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
        try navigateTo3DView()

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
        try navigateTo3DView()

        let viewer = app.descendants(matching: .any)[AXID.muscleMap3DViewer].firstMatch
        XCTAssertTrue(
            viewer.waitForExistence(timeout: 10),
            "3D viewer (ARView container) should exist"
        )
        let controls = app.scrollViews["musclemap-3d-controls"].firstMatch
        if controls.exists {
            XCTAssertTrue(viewer.frame.intersection(controls.frame).isEmpty,
                          "Accessibility controls must not cover the 3D viewport")
        }
        VisualAudit.capture("3D viewer after explicit navigation")
        if controls.exists {
            let mode = app.descendants(matching: .any)[AXID.muscleMap3DModePicker].firstMatch
            for _ in 0..<4 where !mode.isHittable { controls.swipeUp(velocity: .slow) }
            XCTAssertTrue(mode.isHittable, "3D mode controls must be reachable at accessibility sizes")
            VisualAudit.capture("3D accessibility controls after scrolling")
        }
    }

    // MARK: - Helpers

    private func navigateToMuscleMapDetail() {
        let hero = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Activity hero should exist")

        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.activitySectionMuscleMap, maxSwipes: 4))
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.activityMuscleMapDetailLink, maxSwipes: 4),
            "Muscle map detail link should be reachable"
        )
        let detailLink = app.descendants(matching: .any)[AXID.activityMuscleMapDetailLink].firstMatch
        XCTAssertTrue(detailLink.waitForExistence(timeout: 5), "Muscle map detail link should exist")
        detailLink.tap()

        let detailScreen = app.descendants(matching: .any)[AXID.activityMuscleMapDetailScreen].firstMatch
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10), "Muscle Map detail should appear")
    }

    private func navigateTo3DView() throws {
        navigateToMuscleMapDetail()

        let entryLabels = ["3D Muscle Map", "3D 근육맵", "3Dマッスルマップ"]
        let open3D = app.buttons.matching(NSPredicate(format: "label IN %@", entryLabels)).firstMatch
        guard open3D.waitForExistence(timeout: 5) else {
            XCTFail("The original 3D entry should exist")
            return
        }
        if !open3D.isEnabled {
            throw XCTSkip("The original 3D entry is disabled for A04")
        }

        tapFrontChestMuscle()

        let screen3D = app.descendants(matching: .any)[AXID.activityMuscleMap3DScreen].firstMatch
        // Regular-width layouts keep muscle selection in the adjacent detail pane.
        if !screen3D.exists && open3D.exists {
            let primaryScroll = app.scrollViews.firstMatch
            for _ in 0..<4 where !open3D.isHittable { primaryScroll.swipeUp() }
            XCTAssertTrue(open3D.isHittable, "The explicit 3D entry must be reachable")
            open3D.auditTap()
        }
        XCTAssertTrue(screen3D.waitForExistence(timeout: 10), "3D view should appear")
    }

    private func tapFrontChestMuscle() {
        let chestButton = app.buttons["musclemap-body-front-chest"].firstMatch
        XCTAssertTrue(chestButton.waitForExistence(timeout: 10), "Front chest muscle button should exist")
        chestButton.tap()
    }

}
