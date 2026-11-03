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

    func testRegularMuscleMapRecoveryLegendOpensFatigueAlgorithm() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("The expanded recovery legend contract applies to regular iPad")
        }
        var configuration = launchConfiguration
        configuration.additionalArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        launchApp(with: configuration)
        navigateToMuscleMapDetail()

        let map = app.scrollViews["musclemap-detail-map-scroll"].firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 10), "The regular map pane must exist")
        let legend = map.descendants(matching: .any)["activity-muscle-map-legend-recovery"].firstMatch
        XCTAssertTrue(legend.waitForExistence(timeout: 10), "The recovery legend must exist")
        for _ in 0..<16 {
            let window = app.windows.firstMatch
            let viewport = map.frame.intersection(window.frame)
            if !legend.frame.isEmpty && viewport.contains(legend.frame) && legend.isHittable { break }
            let direction: CGFloat = legend.frame.midY < viewport.midY ? 1 : -1
            let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: viewport.midX - window.frame.minX, dy: viewport.midY - window.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: direction * viewport.height * 0.18)))
        }
        XCTAssertFalse(legend.frame.isEmpty)
        XCTAssertTrue(map.frame.intersection(app.windows.firstMatch.frame).contains(legend.frame),
                      "The full recovery legend must fit in the map viewport")
        XCTAssertTrue(legend.isHittable, "The recovery legend must be actionable")
        VisualAudit.capture("A15 A03 recovery legend")
        legend.auditTap()

        let sheet = app.scrollViews["activity-fatigue-algorithm-sheet"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "The legend must open the generic fatigue explanation")
        func reveal(_ id: String) -> XCUIElement {
            let item = sheet.descendants(matching: .any)[id].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 10), "Missing \(id)")
            for _ in 0..<16 {
                let window = app.windows.firstMatch
                let viewport = sheet.frame.intersection(window.frame)
                if !item.frame.isEmpty && viewport.contains(item.frame) { break }
                let direction: CGFloat = item.frame.midY < viewport.midY ? 1 : -1
                let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: viewport.midX - window.frame.minX, dy: viewport.midY - window.frame.minY))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: direction * viewport.height * 0.18)))
            }
            XCTAssertFalse(item.frame.isEmpty)
            XCTAssertTrue(sheet.frame.intersection(app.windows.firstMatch.frame).contains(item.frame),
                          "The full \(id) must fit in the sheet viewport")
            return item
        }
        XCTAssertEqual(reveal("activity-fatigue-algorithm-formula").label, "Fatigue = Σ (Load × e^(-elapsed/τ))")
        VisualAudit.capture("A15 A03 fatigue formula")
        XCTAssertEqual(reveal("activity-fatigue-algorithm-tau").label,
                       "τ = max(2 × recovery hours ÷ max(sleep × readiness, 0.1), 1 hour)")
        VisualAudit.capture("A15 A03 effective tau")
        let grabbers = app.buttons.matching(NSPredicate(format: "label IN %@", ["Sheet Grabber", "Sheet grabber", "시트 손잡이"]))
        XCTAssertEqual(grabbers.count, 1, "The native sheet should expose one visible drag indicator")
        let grabber = grabbers.element(boundBy: 0)
        XCTAssertTrue(grabber.exists && grabber.isHittable, "The native sheet grabber must be reachable")
        let window = app.windows.firstMatch
        XCTAssertTrue(window.frame.contains(grabber.frame), "The grabber must be within the window")
        XCTAssertTrue(sheet.frame.intersects(grabber.frame), "The grabber must overlap the explanation sheet")
        XCTAssertLessThanOrEqual(abs(grabber.frame.midY - sheet.frame.minY), grabber.frame.height,
                                 "The grabber must be at the explanation sheet top edge")
        let endY = min(window.frame.maxY - 60, grabber.frame.midY + window.frame.height * 0.6)
        XCTAssertGreaterThan(endY - grabber.frame.midY, window.frame.height * 0.3)
        let start = grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: grabber.frame.midX - window.frame.minX, dy: endY - window.frame.minY))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "The native sheet must dismiss")
        let detail = app.descendants(matching: .any)[AXID.activityMuscleMapDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "A03 must remain after dismissal")
        VisualAudit.capture("A15 A03 fatigue dismissed")
        let railBack = app.buttons["BackButton"].firstMatch
        if railBack.exists && railBack.isHittable {
            railBack.auditTap()
        } else {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            XCTAssertTrue(back.waitForExistence(timeout: 5), "Native Back must remain available")
            back.auditTap()
        }
        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch.waitForExistence(timeout: 10),
                      "Back must return to Activity")
        VisualAudit.capture("A15 A03 returned to Activity")
    }

    func testRegularMuscleMapSetsLegendOpensVolumeAlgorithm() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("The expanded sets legend contract applies to regular iPad")
        }
        var configuration = launchConfiguration
        configuration.additionalArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        launchApp(with: configuration)
        navigateToMuscleMapDetail()

        let map = app.scrollViews["musclemap-detail-map-scroll"].firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 10), "The regular map pane must exist")
        let mode = map.segmentedControls["activity-muscle-map-mode"].firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        let sets = mode.buttons["Sets"].firstMatch
        XCTAssertTrue(sets.waitForExistence(timeout: 5) && sets.isHittable)
        sets.auditTap()
        let legend = map.descendants(matching: .any)["activity-muscle-map-legend-sets"].firstMatch
        XCTAssertTrue(legend.waitForExistence(timeout: 10), "The sets legend must exist")
        for _ in 0..<16 {
            let window = app.windows.firstMatch
            let viewport = map.frame.intersection(window.frame)
            if !legend.frame.isEmpty && viewport.contains(legend.frame) && legend.isHittable { break }
            let direction: CGFloat = legend.frame.midY < viewport.midY ? 1 : -1
            let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: viewport.midX - window.frame.minX, dy: viewport.midY - window.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: direction * viewport.height * 0.18)))
        }
        XCTAssertFalse(legend.frame.isEmpty)
        XCTAssertTrue(map.frame.intersection(app.windows.firstMatch.frame).contains(legend.frame),
                      "The full sets legend must fit in the map viewport")
        XCTAssertTrue(legend.isHittable, "The sets legend must be actionable")
        VisualAudit.capture("A16 A03 sets legend")
        legend.auditTap()

        let sheet = app.scrollViews["activity-volume-algorithm-sheet"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "The legend must open the weekly volume explanation")
        func reveal(_ id: String) -> XCUIElement {
            let item = sheet.descendants(matching: .any)[id].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 10), "Missing \(id)")
            for _ in 0..<16 {
                let window = app.windows.firstMatch
                let viewport = sheet.frame.intersection(window.frame)
                if !item.frame.isEmpty && viewport.contains(item.frame) { break }
                let direction: CGFloat = item.frame.midY < viewport.midY ? 1 : -1
                let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: viewport.midX - window.frame.minX, dy: viewport.midY - window.frame.minY))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: direction * viewport.height * 0.18)))
            }
            XCTAssertFalse(item.frame.isEmpty)
            XCTAssertTrue(sheet.frame.intersection(app.windows.firstMatch.frame).contains(item.frame),
                          "The full \(id) must fit in the sheet viewport")
            return item
        }
        XCTAssertEqual(reveal("activity-volume-algorithm-formula").label, "Volume = Σ primary sets + Σ max(⌊secondary sets ÷ 2⌋, 1)")
        VisualAudit.capture("A16 A03 volume formula")
        XCTAssertTrue(reveal("activity-volume-algorithm-secondary").label.contains("For each record, halve the completed sets, round down, and credit at least 1 set"))
        VisualAudit.capture("A16 A03 secondary contribution")
        let grabbers = app.buttons.matching(NSPredicate(format: "label IN %@", ["Sheet Grabber", "Sheet grabber", "시트 손잡이"]))
        XCTAssertEqual(grabbers.count, 1, "The native sheet should expose one visible drag indicator")
        let grabber = grabbers.element(boundBy: 0)
        XCTAssertTrue(grabber.exists && grabber.isHittable, "The native sheet grabber must be reachable")
        let window = app.windows.firstMatch
        XCTAssertTrue(window.frame.contains(grabber.frame), "The grabber must be within the window")
        XCTAssertTrue(sheet.frame.intersects(grabber.frame), "The grabber must overlap the explanation sheet")
        XCTAssertLessThanOrEqual(abs(grabber.frame.midY - sheet.frame.minY), grabber.frame.height,
                                 "The grabber must be at the explanation sheet top edge")
        let endY = min(window.frame.maxY - 60, grabber.frame.midY + window.frame.height * 0.6)
        XCTAssertGreaterThan(endY - grabber.frame.midY, window.frame.height * 0.3)
        let start = grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: grabber.frame.midX - window.frame.minX, dy: endY - window.frame.minY))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "The native sheet must dismiss")
        let detail = app.descendants(matching: .any)[AXID.activityMuscleMapDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "A03 must remain after dismissal")
        VisualAudit.capture("A16 A03 volume dismissed")
        let railBack = app.buttons["BackButton"].firstMatch
        if railBack.exists && railBack.isHittable {
            railBack.auditTap()
        } else {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            XCTAssertTrue(back.waitForExistence(timeout: 5), "Native Back must remain available")
            back.auditTap()
        }
        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch.waitForExistence(timeout: 10),
                      "Back must return to Activity")
        VisualAudit.capture("A16 A03 returned to Activity")
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
        var configuration = launchConfiguration
        configuration.additionalArguments += ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        launchApp(with: configuration)
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
        for _ in 0..<8 {
            let entryFrame = open3D.frame
            if visibleMap.contains(entryFrame) { break }
            // A single compact scroll also contains the summary. Reveal the entry in either
            // direction with a short drag so a long swipe cannot repeatedly overshoot it.
            let start = primaryScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
            let end = primaryScroll.coordinate(withNormalizedOffset: CGVector(
                dx: 0.4, dy: entryFrame.minY < visibleMap.minY ? 0.7 : 0.3
            ))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertTrue(visibleMap.contains(open3D.frame), "The disabled 3D entry should remain visible on the map")
        XCTAssertFalse(open3D.isEnabled, "Selecting a 2D muscle should not enable the 3D entry")
        addScreenshotAttachment(named: "A03 2D muscle selection and disabled 3D entry")
        VisualAudit.capture("A03 2D muscle selection and disabled 3D entry")

        let summaryScroll = app.scrollViews["musclemap-detail-summary-scroll"].firstMatch
        let compactScroll = app.scrollViews["musclemap-detail-map-scroll"].firstMatch
        let detailScroll = summaryScroll.exists ? summaryScroll : compactScroll
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5), "The selected muscle's actual pane should exist")
        XCTAssertTrue(detailScroll.descendants(matching: .any)["musclemap-detail-selected-muscle"].firstMatch.exists,
                      "The selected detail should belong to the chosen pane")
        for identifier in ["activity-muscle-detail-inline-title", "activity-muscle-detail-status",
                           "activity-muscle-detail-value-fatigue", "activity-muscle-detail-value-weekly-volume",
                           "activity-muscle-detail-value-last-trained", "activity-muscle-detail-value-sleep-modifier"] {
            let element = inlineDetail.descendants(matching: .any)[identifier].firstMatch
            for _ in 0..<16 {
                let viewport = detailScroll.frame.intersection(app.windows.firstMatch.frame)
                if element.exists && !element.frame.isEmpty && viewport.contains(element.frame) { break }
                if element.exists && element.frame.midY < viewport.midY {
                    detailScroll.swipeDown(velocity: .slow)
                } else {
                    detailScroll.swipeUp(velocity: .slow)
                }
            }
            XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing selected inline \(identifier)")
            XCTAssertFalse(element.label.isEmpty)
            XCTAssertFalse(element.frame.isEmpty)
            XCTAssertTrue(detailScroll.frame.intersection(app.windows.firstMatch.frame).contains(element.frame),
                          "Selected inline \(identifier) should fit in its viewport")
            if identifier == "activity-muscle-detail-inline-title" {
                XCTAssertTrue(["Chest", "가슴", "胸"].contains(element.label), element.label)
            }
            VisualAudit.capture("A13 inline selected \(identifier)")
        }
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
        for title in ["운동 부하 (14일)", "생체 보정"] {
            let heading = explanation.staticTexts[title].firstMatch
            XCTAssertTrue(heading.waitForExistence(timeout: 5), "The Korean calculation heading must be translated")
            XCTAssertFalse(heading.frame.isEmpty)
            XCTAssertTrue(explanation.frame.intersection(app.windows.firstMatch.frame).contains(heading.frame),
                          "The complete Korean heading must fit in the sheet")
        }
        VisualAudit.capture("A14 Korean calculation headings")
        // A14 child values: actual localized values, never fixed fixture numbers.
        func visibleFatigueValue(_ suffix: String) -> XCUIElement {
            let value = explanation.staticTexts["activity-fatigue-info-" + suffix].firstMatch
            for _ in 0..<16 {
                let window = app.windows.firstMatch
                let viewport = explanation.frame.intersection(window.frame)
                if value.exists && !value.frame.isEmpty && viewport.contains(value.frame) { break }
                let direction: CGFloat = value.exists && value.frame.midY < viewport.midY ? 1 : -1
                let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: viewport.midX - window.frame.minX, dy: viewport.midY - window.frame.minY))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: direction * viewport.height * 0.18)))
            }
            XCTAssertTrue(value.waitForExistence(timeout: 5), "Missing inline fatigue \(suffix)")
            XCTAssertFalse(value.label.isEmpty)
            XCTAssertFalse(value.frame.isEmpty)
            XCTAssertTrue(explanation.frame.intersection(app.windows.firstMatch.frame).contains(value.frame),
                          "The complete inline fatigue \(suffix) must fit")
            VisualAudit.capture("A14 inline fatigue \(suffix)")
            return value
        }
        _ = visibleFatigueValue("level")
        if explanation.staticTexts["activity-fatigue-info-contribution-raw"].firstMatch.exists {
            _ = visibleFatigueValue("contribution-raw")
            _ = visibleFatigueValue("contribution-decayed")
            _ = visibleFatigueValue("subtotal")
        } else {
            XCTAssertTrue(explanation.staticTexts.matching(NSPredicate(format: "label IN %@", ["No workout records", "운동 기록 없음", "ワークアウト記録なし"])).firstMatch.exists)
        }
        for suffix in ["sleep-value", "readiness-value", "result-value", "result-level", "tau-value"] {
            _ = visibleFatigueValue(suffix)
        }
        addScreenshotAttachment(named: "A03 selected muscle fatigue calculation")
        VisualAudit.capture("A03 selected muscle fatigue calculation")

        // This iPad presentation exposes the native sheet as a scroll view with a drag indicator,
        // not as an XCUIElementTypeSheet. Use the single observed system grabber.
        let grabbers = app.buttons.matching(NSPredicate(format: "label IN %@", ["Sheet Grabber", "Sheet grabber", "시트 손잡이"]))
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
