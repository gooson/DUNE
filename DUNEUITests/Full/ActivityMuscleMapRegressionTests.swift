@preconcurrency import XCTest
import UIKit

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

    func testRegularMuscleMapShowsFrontCalvesWithoutScrolling() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("The two-pane first-viewport contract applies to regular iPad layout")
        }
        navigateToMuscleMapDetail()

        let mapScroll = app.scrollViews["musclemap-detail-map-scroll"].firstMatch
        let summaryScroll = app.scrollViews["musclemap-detail-summary-scroll"].firstMatch
        XCTAssertTrue(mapScroll.waitForExistence(timeout: 10) && summaryScroll.waitForExistence(timeout: 10),
                      "Regular Muscle Map should expose both native pane scroll views")
        let header = summaryScroll.descendants(matching: .any)["musclemap-detail-header"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5),
                      "The recovery header should start the secondary pane on regular iPad")
        let frontCalves = mapScroll.buttons["musclemap-body-front-calves"].firstMatch
        XCTAssertTrue(frontCalves.waitForExistence(timeout: 5),
                      "The original front calf hit target should remain in the SVG map")
        let firstViewport = mapScroll.frame.intersection(app.windows.firstMatch.frame)
        XCTAssertTrue(firstViewport.contains(frontCalves.frame),
                      "The complete front calf hit target should fit in the first map viewport without scrolling")
        addScreenshotAttachment(named: "A03 regular full-body first viewport")
        VisualAudit.capture("A03 regular full-body first viewport")
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
        let calculation = app.buttons["activity-muscle-detail-calculation"].firstMatch
        XCTAssertTrue(calculation.waitForExistence(timeout: 5),
                      "The selected muscle should retain its calculation button accessibility ID")
        XCTAssertFalse(screen3D.exists, "Muscle selection should not open the 3D viewer")
        let primaryScroll = app.scrollViews.firstMatch
        let visibleMap = primaryScroll.frame.intersection(app.windows.firstMatch.frame)
        for _ in 0..<8 where !visibleMap.contains(open3D.frame) { primaryScroll.swipeUp() }
        XCTAssertTrue(visibleMap.contains(open3D.frame), "The disabled 3D entry should remain visible on the map")
        XCTAssertFalse(open3D.isEnabled, "Selecting a 2D muscle should not enable the 3D entry")
        addScreenshotAttachment(named: "A03 2D muscle selection and disabled 3D entry")
        VisualAudit.capture("A03 2D muscle selection and disabled 3D entry")

        let detailScroll = app.scrollViews.element(boundBy: app.scrollViews.count > 1 ? 1 : 0)
        for _ in 0..<8 where !calculation.isHittable { detailScroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(calculation.isHittable, "The selected muscle's calculation action should be reachable")
        addScreenshotAttachment(named: "A03 selected muscle detail before calculation")
        VisualAudit.capture("A03 selected muscle detail before calculation")
        calculation.auditTap()
        let explanation = app.scrollViews["activity-fatigue-info-sheet"].firstMatch
        XCTAssertTrue(explanation.waitForExistence(timeout: 5), "Calculation should open the real fatigue explanation")
        let calculationTitle = explanation.staticTexts.matching(NSPredicate(
            format: "label IN %@", ["Fatigue Calculation", "피로도 계산", "疲労度計算"]
        )).firstMatch
        XCTAssertTrue(calculationTitle.waitForExistence(timeout: 5),
                      "The calculation sheet should expose its existing localized title")
        addScreenshotAttachment(named: "A03 selected muscle fatigue calculation")
        VisualAudit.capture("A03 selected muscle fatigue calculation")

        // This iPad presentation exposes the native sheet as a scroll view with a drag indicator,
        // not as an XCUIElementTypeSheet. Use the single observed system grabber.
        let grabbers = app.buttons.matching(NSPredicate(format: "label == %@", "시트 손잡이"))
        XCTAssertEqual(grabbers.count, 1, "The native sheet should expose one visible drag indicator")
        let grabber = grabbers.element(boundBy: 0)
        XCTAssertTrue(grabber.exists && grabber.isHittable, "The native sheet drag indicator should be reachable")
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists && window.frame.contains(explanation.frame),
                      "Calculation content should be inside the active window")
        XCTAssertTrue(window.frame.contains(grabber.frame) && explanation.frame.intersects(grabber.frame),
                      "The native drag indicator should overlap the calculation sheet's top edge")
        XCTAssertLessThanOrEqual(abs(grabber.frame.midY - explanation.frame.minY), grabber.frame.height,
                                 "The native drag indicator should be at the calculation sheet's top edge")
        let endY = min(window.frame.maxY - 60, grabber.frame.midY + window.frame.height * 0.6)
        XCTAssertGreaterThan(endY - grabber.frame.midY, window.frame.height * 0.3,
                             "The dismiss drag should travel down inside the window")
        let start = grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: grabber.frame.midX - window.frame.minX,
                                 dy: endY - window.frame.minY))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(explanation.waitForNonExistence(timeout: 5),
                      "Calculation sheet should dismiss by its drag indicator")
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 5), "The 2D map should remain after sheet dismissal")
        XCTAssertTrue(inlineDetail.waitForExistence(timeout: 5), "The selected muscle should remain inline")

        let railBack = app.buttons["BackButton"].firstMatch
        if railBack.exists && railBack.isHittable {
            railBack.auditTap()
        } else {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            XCTAssertTrue(back.waitForExistence(timeout: 5), "Native Back should remain available")
            back.auditTap()
        }
        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
            .waitForExistence(timeout: 10), "Back should return to Activity")
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
