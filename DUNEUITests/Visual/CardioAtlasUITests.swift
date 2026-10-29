@preconcurrency import XCTest

/// Native screenshots use the opt-in synthetic route and place fixtures.
@MainActor
final class CardioAtlasUITests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-cardio-atlas-fixture", "--ui-cardio-place-search-fixture",
         "-morningBriefingDisabled", "YES"]
    }

    func testRecordedRouteDetailAndProgress() {
        openRecord("running")
        XCTAssertTrue(element("cardio-atlas-section").waitForExistence(timeout: 10))
        XCTAssertTrue(element("cardio-atlas-map").exists)
        XCTAssertLessThanOrEqual(
            element("cardio-atlas-place").frame.height,
            element("cardio-atlas-share").frame.height + 1,
            "Header actions should retain the same single-line height"
        )
        atlasScreenshot(named: "Cardio Atlas recorded route detail")

        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-journey"))
        element("cardio-atlas-journey").tap()
        assertAtlasDestinationVisible("cardio-atlas-journey-detail")
        atlasScreenshot(named: "Cardio Atlas Journey progress")
        closeAtlasDestination()
    }

    func testImportedCardioDetailPreservesAnalysis() {
        navigateToDashboard()
        XCTAssertTrue(element(AXID.dashboardHeroCondition).waitForExistence(timeout: 12))
        let notifications = element(AXID.dashboardToolbarNotifications)
        XCTAssertTrue(notifications.waitForExistence(timeout: 8))
        notifications.tap()
        XCTAssertTrue(element(AXID.notificationHubScreen).waitForExistence(timeout: 8))
        let row = element(AXID.notificationWorkoutRow("ui-test-activity-workout-running"))
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()
        XCTAssertTrue(element("healthkit-workout-detail-screen").waitForExistence(timeout: 10))
        XCTAssertTrue(element("cardio-atlas-section").waitForExistence(timeout: 10))
        XCTAssertTrue(element("healthkit-workout-edit-title").exists)
        atlasScreenshot(named: "Cardio Atlas imported HealthKit detail")
    }

    func testPassportFromRecordedRoute() {
        openRecord("running")
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-passport"))
        element("cardio-atlas-passport").tap()
        assertAtlasDestinationVisible("cardio-atlas-passport-detail")
        atlasScreenshot(named: "Cardio Atlas Passport progress")
        closeAtlasDestination()
    }

    func testShareStylesAndPrivateLocationDefault() {
        openRecord("running")
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-share"))
        element("cardio-atlas-share").tap()
        assertAtlasDestinationVisible("cardio-atlas-share-screen")
        XCTAssertTrue(element("cardio-atlas-share-preview").waitForExistence(timeout: 10))
        let location = element("cardio-atlas-share-location")
        XCTAssertTrue(location.exists)
        XCTAssertEqual(location.value as? String, "0", "Location sharing should start off")
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        assertAtlasShareFitsWidth()
        atlasScreenshot(named: "Cardio Atlas share private Atlas")

        visibleAtlasShareControl("cardio-atlas-share-location").tap()
        XCTAssertEqual(location.value as? String, "1")
        XCTAssertTrue(element("cardio-atlas-share-trim").exists)
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        _ = visibleAtlasShareControl("style-cardio-atlas-atlas", direction: .down)
        assertAtlasShareFitsWidth()
        atlasScreenshot(named: "Cardio Atlas share Atlas route")

        visibleAtlasShareControl("cardio-atlas-share-location").tap()
        XCTAssertEqual(location.value as? String, "0")
        XCTAssertTrue(element("cardio-atlas-share-map-image").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        _ = visibleAtlasShareControl("style-cardio-atlas-atlas", direction: .down)
        assertAtlasShareFitsWidth()
        atlasScreenshot(named: "Cardio Atlas location removed from shared image")
        visibleAtlasShareControl("cardio-atlas-share-location").tap()
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))

        let ribbon = element("style-cardio-atlas-paceRibbon")
        XCTAssertTrue(ribbon.exists && ribbon.isEnabled)
        visibleAtlasShareControl("style-cardio-atlas-paceRibbon", direction: .down).tap()
        XCTAssertTrue(ribbon.isSelected)
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        _ = visibleAtlasShareControl("style-cardio-atlas-atlas", direction: .down)
        assertAtlasShareFitsWidth()
        atlasScreenshot(named: "Cardio Atlas share Pace Ribbon")

        visibleAtlasShareControl("style-cardio-atlas-signature", direction: .down).tap()
        XCTAssertTrue(element("style-cardio-atlas-signature").isSelected)
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        _ = visibleAtlasShareControl("style-cardio-atlas-atlas", direction: .down)
        assertAtlasShareFitsWidth()
        atlasScreenshot(named: "Cardio Atlas share Signature")
        closeAtlasDestination()
    }

    func testIndoorPlacePickerCancelPreservesPlace() {
        openRecord("elliptical")
        XCTAssertTrue(element("cardio-atlas-map").waitForExistence(timeout: 10))
        atlasScreenshot(named: "Cardio Atlas indoor place")
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-place"))
        element("cardio-atlas-place").tap()
        XCTAssertTrue(element("cardio-atlas-place-cancel").waitForExistence(timeout: 8))
        XCTAssertTrue(element("cardio-atlas-place-remove").exists)
        atlasScreenshot(named: "Cardio Atlas selected place editor")
        element("cardio-atlas-place-cancel").tap()
        XCTAssertTrue(element("cardio-atlas-map").waitForExistence(timeout: 8))
    }

    func testUnlocatedCardioShowsActualEmptyState() {
        openRecord("rowing-machine")
        XCTAssertTrue(element("cardio-atlas-map").waitForExistence(timeout: 10))
        XCTAssertTrue(element("cardio-atlas-map-empty").exists)
        atlasScreenshot(named: "Cardio Atlas location not recorded")
    }

    func testSearchSelectionScrollsToTopAndUpdatesMap() {
        openRecord("rowing-machine")
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-place"))
        element("cardio-atlas-place").tap()
        searchForTestPlaces()

        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "cardio-atlas-place-result-"))
        XCTAssertEqual(rows.firstMatch.identifier, "cardio-atlas-place-result-Atlas Test Gym 1",
                       "Synthetic results arrive farthest first and should display nearest first")
        selectTestPlace(18)
        assertSelectedTestPlaceVisible(18)
        atlasScreenshot(named: "Cardio Atlas searched place scrolled to top")

        searchForTestPlaces()
        selectTestPlace(2)
        assertSelectedTestPlaceVisible(2)
        atlasScreenshot(named: "Cardio Atlas changed selection map")

        // Selecting the same result must reveal the selection again, too.
        searchForTestPlaces()
        selectTestPlace(2)
        assertSelectedTestPlaceVisible(2)
        let confirm = element("cardio-atlas-place-confirm")
        XCTAssertTrue(confirm.exists && confirm.isHittable, "Selection must expose a visible save action")
        XCTAssertFalse(element("cardio-atlas-place-save").exists, "Keep one primary save action")
        confirm.tap()
        XCTAssertTrue(element("cardio-atlas-map").waitForExistence(timeout: 8))
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-place"))
        element("cardio-atlas-place").tap()
        assertSelectedTestPlaceVisible(2)
        atlasScreenshot(named: "Cardio Atlas saved search place reopened")
    }

    /// One drag only: establishes recovery of the previously intercepted gesture.
    /// It does not select/save or replace the full long-list regression.
    func testPlaceSearchKeyboardGeometryRecoveryProbe() {
        openRecord("rowing-machine")
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-place"))
        element("cardio-atlas-place").tap()
        searchForTestPlaces()
        let row = element("cardio-atlas-place-result-Atlas Test Gym 1")
        let before = row.frame
        atlasScreenshot(named: "Place keyboard recovery before single drag")
        addProbeHierarchy("before")
        guard dragTestPlaceResultsOnce(recordGeometry: true) else { return }
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !row.exists || row.frame.minY < before.minY - 5
        }, object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 5), .completed,
                       "A real list movement is required; geometry alone is insufficient")
        atlasScreenshot(named: "Place keyboard recovery after single drag")
        addProbeHierarchy("after")
    }

    private func addProbeHierarchy(_ phase: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = "Place keyboard recovery \(phase) AX"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSearchSelectionCancelPreservesOriginalPlace() {
        openRecord("elliptical")
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-place"))
        element("cardio-atlas-place").tap()
        let selection = element("cardio-atlas-place-selection")
        XCTAssertTrue(selection.waitForExistence(timeout: 8))
        let originalPlace = selection.label
        searchForTestPlaces()
        selectTestPlace(18)
        assertSelectedTestPlaceVisible(18)
        element("cardio-atlas-place-cancel").tap()
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-place"))
        element("cardio-atlas-place").tap()
        XCTAssertTrue(selection.waitForExistence(timeout: 8))
        XCTAssertEqual(selection.label, originalPlace)
    }

    func testKoreanWordAndInitialSearchExcludeUnrelatedPlaces() {
        openRecord("rowing-machine")
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-place"))
        element("cardio-atlas-place").tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        field.typeText("헬스")
        XCTAssertTrue(element("cardio-atlas-place-result-헬스플러스").waitForExistence(timeout: 8))
        XCTAssertFalse(element("cardio-atlas-place-result-Danubius Hotel Helia").exists)
        XCTAssertFalse(element("cardio-atlas-place-result-서울숲 수영장").exists)
        atlasScreenshot(named: "Cardio Atlas Korean word search")

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
        field.typeText("ㅎㅅ")
        XCTAssertTrue(element("cardio-atlas-place-result-헬스플러스").waitForExistence(timeout: 8))
        XCTAssertFalse(element("cardio-atlas-place-result-Danubius Hotel Helia").exists)
        atlasScreenshot(named: "Cardio Atlas Korean initial search")
        element("cardio-atlas-place-result-헬스플러스").tap()
        let confirm = element("cardio-atlas-place-confirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: 8))
        XCTAssertTrue(confirm.isHittable)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        atlasScreenshot(named: "Cardio Atlas Korean selection save action")
        confirm.tap()
        XCTAssertTrue(element("cardio-atlas-map").waitForExistence(timeout: 8))
    }

    private func searchForTestPlaces() {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5),
                      "The software keyboard must be visible for this regression")
        if let value = field.value as? String, value.contains("Atlas") {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText("Atlas")
        XCTAssertTrue(element("cardio-atlas-place-result-Atlas Test Gym 1").waitForExistence(timeout: 8))
    }

    private func selectTestPlace(_ index: Int) {
        let row = element("cardio-atlas-place-result-Atlas Test Gym \(index)")
        for _ in 0..<15 {
            if row.exists && row.isHittable { break }
            guard dragTestPlaceResultsOnce() else { return }
        }
        atlasScreenshot(named: "Cardio Atlas search results before selection \(index)")
        XCTAssertTrue(row.exists && row.isHittable)
        row.tap()
    }

    @discardableResult
    private func dragTestPlaceResultsOnce(recordGeometry: Bool = false) -> Bool {
        let list = element("cardio-atlas-place-picker")
        let keyboard = app.keyboards.firstMatch
        let field = app.searchFields.firstMatch
        var bottom = keyboard.exists ? min(list.frame.maxY, keyboard.frame.minY) : list.frame.maxY
        let confirm = element("cardio-atlas-place-confirm")
        if confirm.exists && confirm.isHittable { bottom = min(bottom, confirm.frame.minY) }
        let start = CGPoint(x: list.frame.midX, y: bottom - 100)
        let end = CGPoint(x: list.frame.midX, y: max(list.frame.minY + 50, bottom - 240))
        // The native keyboard AX frame omits its 44pt prediction strip on this
        // device. Reserve 60pt above it and confirm that envelope in probe PNGs.
        let stripGuardTop = keyboard.exists ? keyboard.frame.minY - 60 : list.frame.maxY
        let top = max(list.frame.minY, field.frame.maxY + 12)
        let safe = list.frame.contains(start) && list.frame.contains(end)
            && start.y > end.y && end.y > top && start.y < stripGuardTop
            && (!confirm.exists || !confirm.isHittable || start.y < confirm.frame.minY)
            && !app.toolbars.allElementsBoundByIndex.contains {
                $0.isHittable && ($0.frame.contains(start) || $0.frame.contains(end))
            }
        if recordGeometry {
            let details = "list=\(list.frame); field=\(field.frame); keyboard=\(keyboard.frame); "
                + "predictionGuardTop=\(stripGuardTop); confirm=\(confirm.exists ? confirm.frame : .zero); "
                + "start=\(start); end=\(end); safe=\(safe)"
            let attachment = XCTAttachment(string: details)
            attachment.name = "Place keyboard recovery exact geometry"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        guard safe else {
            XCTFail("Unsafe drag geometry: do not retry inside keyboard/navigation overlays")
            return false
        }
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: start.x, dy: start.y))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: end.x, dy: end.y)))
        return true
    }

    private func assertSelectedTestPlaceVisible(_ index: Int, file: StaticString = #filePath, line: UInt = #line) {
        let selection = element("cardio-atlas-place-selection")
        let map = element("cardio-atlas-place-selection-map")
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            selection.exists && selection.isHittable
                && selection.label.contains("Atlas Test Gym \(index)")
                && map.exists && map.isHittable
                && !self.app.keyboards.firstMatch.exists
                && self.app.frame.contains(selection.frame)
        }, object: selection)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 8), .completed, file: file, line: line)
    }

}


/// Launch once with large text: avoids a second app installation/reset during setup.
@MainActor
final class CardioAtlasLargeTextUITests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-cardio-atlas-fixture", "-morningBriefingDisabled", "YES",
         "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
         "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    }

    func testKoreanLargeTextDetailAndPassport() {
        openRecord("running")
        XCTAssertTrue(element("cardio-atlas-section").waitForExistence(timeout: 10))
        let placeAction = element("cardio-atlas-place").frame
        XCTAssertGreaterThan(placeAction.width, placeAction.height, "Large-text action should not stack syllables")
        atlasScreenshot(named: "Cardio Atlas Korean large text detail")
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-passport"))
        element("cardio-atlas-passport").tap()
        assertAtlasDestinationVisible("cardio-atlas-passport-detail")
        atlasScreenshot(named: "Cardio Atlas Korean large text Passport")
        closeAtlasDestination()
    }

}

@MainActor
final class CardioAtlasShareCompactDarkUITests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-cardio-atlas-fixture", "--ui-test-style", "dark",
         "-morningBriefingDisabled", "YES", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
    }

    func testKoreanDarkShareStylesUseCompactRow() {
        openRecord("running")
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-share"))
        element("cardio-atlas-share").tap()
        assertAtlasDestinationVisible("cardio-atlas-share-screen")
        let atlas = element("style-cardio-atlas-atlas")
        let ribbon = element("style-cardio-atlas-paceRibbon")
        let signature = element("style-cardio-atlas-signature")
        let preview = element("cardio-atlas-share-preview")
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        let frames = [atlas.frame, ribbon.frame, signature.frame]
        for frame in frames {
            XCTAssertGreaterThanOrEqual(frame.height, 44)
            XCTAssertLessThanOrEqual(frame.height, 56)
            XCTAssertTrue(app.frame.contains(frame), "Every style button should fit the initial viewport")
        }
        XCTAssertLessThanOrEqual(abs(frames[0].midY - frames[1].midY), 2)
        XCTAssertLessThanOrEqual(abs(frames[1].midY - frames[2].midY), 2)
        XCTAssertLessThanOrEqual(abs(frames[0].width - frames[1].width), 2)
        XCTAssertLessThanOrEqual(abs(frames[1].width - frames[2].width), 2)
        XCTAssertLessThan(frames[0].maxX, frames[1].minX)
        XCTAssertLessThan(frames[1].maxX, frames[2].minX)
        let previewGap = preview.frame.minY - (frames.map(\.maxY).max() ?? 0)
        XCTAssertGreaterThanOrEqual(previewGap, 0)
        XCTAssertLessThanOrEqual(previewGap, 20)
        XCTAssertLessThan(preview.frame.minY, app.frame.maxY)
        XCTAssertTrue(atlas.isSelected)
        XCTAssertEqual(element("cardio-atlas-share-location").value as? String, "0")
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 15))
        atlasScreenshot(named: "Cardio Atlas compact Korean dark Atlas")

        visibleAtlasShareControl("style-cardio-atlas-paceRibbon").tap()
        XCTAssertTrue(ribbon.isSelected)
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 15))
        atlasScreenshot(named: "Cardio Atlas compact Korean dark Pace Ribbon")

        visibleAtlasShareControl("style-cardio-atlas-signature").tap()
        XCTAssertTrue(signature.isSelected)
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 15))
        atlasScreenshot(named: "Cardio Atlas compact Korean dark Signature")
    }
}

@MainActor
final class CardioAtlasShareCompactAXDarkUITests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-cardio-atlas-fixture", "--ui-test-style", "dark",
         "-morningBriefingDisabled", "YES", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
         "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    }

    func testKoreanAXDarkShareStylesStackAndRemainUsable() {
        openRecord("running")
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-share"))
        element("cardio-atlas-share").tap()
        assertAtlasDestinationVisible("cardio-atlas-share-screen")
        let atlas = element("style-cardio-atlas-atlas")
        let ribbon = element("style-cardio-atlas-paceRibbon")
        let signature = element("style-cardio-atlas-signature")
        XCTAssertTrue(atlas.waitForExistence(timeout: 10))
        XCTAssertTrue(ribbon.exists && signature.exists)
        XCTAssertLessThan(atlas.frame.maxY, ribbon.frame.minY)
        XCTAssertLessThan(ribbon.frame.maxY, signature.frame.minY)
        XCTAssertTrue(visibleAtlasShareControl("style-cardio-atlas-atlas").isHittable)
        XCTAssertTrue(visibleAtlasShareControl("style-cardio-atlas-paceRibbon").isHittable)
        let visibleSignature = visibleAtlasShareControl("style-cardio-atlas-signature")
        XCTAssertTrue(visibleSignature.isHittable)
        atlasScreenshot(named: "Cardio Atlas compact Korean AX dark selector")
        visibleSignature.tap()
        XCTAssertTrue(signature.isSelected)
        let action = element("cardio-atlas-share-action")
        XCTAssertTrue(action.waitForExistence(timeout: 15))
        XCTAssertTrue(visibleAtlasShareControl("cardio-atlas-share-action").isEnabled)
        XCTAssertEqual(element("cardio-atlas-share-location").value as? String, "0")
        atlasScreenshot(named: "Cardio Atlas compact Korean AX dark Signature")
    }
}

@MainActor
final class CardioAtlasShareModalDarkUITests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-cardio-atlas-fixture", "--ui-test-style", "dark",
         "-morningBriefingDisabled", "YES", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
    }

    func testKoreanDarkShareModalSurvivesBodySwipesAndDismissesFromHeader() {
        verifyAtlasShareModalGestures(appearance: "dark")
    }
}

@MainActor
final class CardioAtlasShareModalLightUITests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-cardio-atlas-fixture", "--ui-test-style", "light",
         "-morningBriefingDisabled", "YES", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
    }

    func testKoreanLightShareModalSurvivesBodySwipesAndDismissesFromHeader() {
        verifyAtlasShareModalGestures(appearance: "light")
    }
}

@MainActor
final class CardioAtlasShareModalAXDarkUITests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-cardio-atlas-fixture", "--ui-test-style", "dark",
         "-morningBriefingDisabled", "YES", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
         "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    }

    func testLongShareContentSurvivesScrollingAndHeaderDismissal() {
        verifyAtlasShareModalGestures(appearance: "AX dark")
    }
}

@MainActor
final class CardioAtlasCountMilestoneUITests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-cardio-atlas-fixture", "--ui-cardio-count-milestones", "--ui-test-style", "dark",
         "-morningBriefingDisabled", "YES", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
    }

    func testPassportShowsHundredCountMilestonesAndNextTarget() {
        openRecord("running")
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-passport"))
        element("cardio-atlas-passport").tap()
        assertAtlasDestinationVisible("cardio-atlas-passport-detail")
        let scroll = element("cardio-atlas-passport-detail")
        let twoHundred = element("cardio-passport-earned-running-sessionCount-200")
        let threeHundred = element("cardio-passport-earned-running-sessionCount-300")
        for _ in 0..<8 {
            if twoHundred.exists && twoHundred.isHittable && threeHundred.exists && threeHundred.isHittable {
                break
            }
            scroll.swipeUp()
        }
        XCTAssertTrue(twoHundred.exists && twoHundred.isHittable)
        XCTAssertTrue(threeHundred.exists && threeHundred.isHittable)
        atlasScreenshot(named: "Cardio Atlas Passport 200 and 300 workouts")

        let next = element("cardio-passport-next-running-sessionCount-400")
        for _ in 0..<6 {
            if next.exists && next.isHittable { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(next.exists && next.isHittable)
        atlasScreenshot(named: "Cardio Atlas Passport next 400 workouts")
        let done = element("cardio-atlas-destination-close")
        for _ in 0..<4 where !done.exists || !done.isHittable { scroll.swipeDown() }
        XCTAssertTrue(done.exists && done.isHittable)
        done.tap()
        assertAtlasDestinationVisible("exercise-session-detail-scroll")
    }
}

@MainActor
private extension UITestBaseCase {
    func atlasScreenshot(named name: String) {
        addScreenshotAttachment(named: name)
        if ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_HOST_ONLY"] == "1" {
            VisualAudit.capture(name)
        }
    }

    func openRecord(_ definitionID: String) {
        navigateToActivity()
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.activityRecentSeeAll, maxSwipes: 20))
        if definitionID == "running" { atlasScreenshot(named: "Cardio Atlas recent cardio records") }
        app.buttons[AXID.activityRecentSeeAll].firstMatch.tap()
        XCTAssertTrue(element(AXID.exerciseViewScreen).waitForExistence(timeout: 10))
        let rowID = "exercise-row-\(definitionID)"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(rowID, maxSwipes: 8))
        if definitionID == "running" { atlasScreenshot(named: "Cardio Atlas local cardio workout list") }
        element(rowID).tap()
        XCTAssertTrue(element("exercise-session-detail-scroll").waitForExistence(timeout: 8))
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func verifyAtlasShareModalGestures(appearance: String, file: StaticString = #filePath, line: UInt = #line) {
        openRecord("running")
        openAtlasShareModal(file: file, line: line)
        XCTAssertEqual(element("cardio-atlas-share-location").value as? String, "0", file: file, line: line)
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 15), file: file, line: line)
        atlasScreenshot(named: "Cardio Atlas \(appearance) share modal initial")

        for _ in 0..<2 {
            dragAtlasShareBody(up: true)
            assertAtlasShareModalHasVisibleContent(file: file, line: line)
        }
        dragAtlasShareBody(up: false)
        if !element("cardio-atlas-share-screen").exists {
            assertAtlasDestinationVisible("exercise-session-detail-scroll", file: file, line: line)
            openAtlasShareModal(file: file, line: line)
        } else {
            assertAtlasShareModalHasVisibleContent(file: file, line: line)
        }
        _ = visibleAtlasShareControl("style-cardio-atlas-atlas", direction: .down, file: file, line: line)
        for identifier in ["style-cardio-atlas-atlas", "style-cardio-atlas-paceRibbon",
                           "style-cardio-atlas-signature"] {
            XCTAssertTrue(element(identifier).isHittable, identifier, file: file, line: line)
        }
        let done = element("cardio-atlas-destination-close")
        for _ in 0..<3 where !done.exists || !done.isHittable {
            element("cardio-atlas-share-screen").swipeDown()
        }
        XCTAssertTrue(done.exists && done.isHittable, file: file, line: line)
        XCTAssertLessThan(done.frame.midY, app.frame.midY, file: file, line: line)
        atlasScreenshot(named: "Cardio Atlas \(appearance) share modal after body swipes")

        if appearance == "dark" {
            for (style, title) in [("paceRibbon", "Pace Ribbon"), ("signature", "Signature")] {
                element("style-cardio-atlas-\(style)").tap()
                XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 15), file: file, line: line)
                atlasScreenshot(named: "Cardio Atlas dark share modal \(title)")
            }
        }

        let grabbers = app.buttons.matching(NSPredicate(format: "label == %@", "시트 손잡이"))
        guard let grabber = grabbers.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("The visible modal drag handle must be available", file: file, line: line)
            return
        }
        let start = grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: element("cardio-atlas-share-screen").frame.midX,
                                 dy: min(app.frame.maxY - 60, grabber.frame.midY + app.frame.height * 0.6)))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(element("cardio-atlas-share-screen").waitForNonExistence(timeout: 5), file: file, line: line)
        assertAtlasDestinationVisible("exercise-session-detail-scroll", file: file, line: line)
        atlasScreenshot(named: "Cardio Atlas \(appearance) share modal header dismissed")

        openAtlasShareModal(file: file, line: line)
        XCTAssertTrue(element("cardio-atlas-share-preview").waitForExistence(timeout: 10), file: file, line: line)
        atlasScreenshot(named: "Cardio Atlas \(appearance) share modal reopened")
        closeAtlasDestination(file: file, line: line)
    }

    func openAtlasShareModal(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(scrollToAtlasDetailControl("cardio-atlas-share"), file: file, line: line)
        element("cardio-atlas-share").tap()
        assertAtlasDestinationVisible("cardio-atlas-share-screen", file: file, line: line)
    }

    func dragAtlasShareBody(up: Bool) {
        let viewport = element("cardio-atlas-share-screen").frame.intersection(app.frame)
        let x = viewport.minX + min(12, viewport.width * 0.05)
        let startY = viewport.minY + viewport.height * (up ? 0.72 : 0.38)
        let endY = up ? max(viewport.minY + 72, startY - 220)
            : min(viewport.maxY - 40, startY + 220)
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: startY))
        let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: endY))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    func assertAtlasShareModalHasVisibleContent(file: StaticString = #filePath, line: UInt = #line) {
        let share = element("cardio-atlas-share-screen")
        XCTAssertTrue(share.exists, file: file, line: line)
        let viewport = share.frame.intersection(app.frame)
        XCTAssertGreaterThan(viewport.height, app.frame.height * 0.4,
                             "The share sheet must retain its body height", file: file, line: line)
        let identifiers = ["cardio-atlas-share-preview", "style-cardio-atlas-atlas",
                           "style-cardio-atlas-paceRibbon", "style-cardio-atlas-signature",
                           "cardio-atlas-share-location", "cardio-atlas-share-action"]
        let hasVisibleControl = identifiers.contains { identifier in
            let control = element(identifier)
            return control.exists && control.isHittable && control.frame.intersects(viewport)
        }
        XCTAssertTrue(hasVisibleControl, "A card or control must remain visible after scrolling", file: file, line: line)
    }

    func scrollToAtlasDetailControl(_ identifier: String) -> Bool {
        let control = app.descendants(matching: .any)[identifier].firstMatch
        let scroll = app.descendants(matching: .any)["exercise-session-detail-scroll"].firstMatch
        for _ in 0..<12 {
            let viewport = scroll.frame.intersection(app.frame).insetBy(dx: 0, dy: 12)
            if control.exists && control.isHittable && viewport.contains(CGPoint(x: control.frame.midX, y: control.frame.midY)) {
                return true
            }
            let revealAbove = control.exists && control.frame.midY < viewport.minY
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: revealAbove ? 0.4 : 0.65))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: revealAbove ? 0.65 : 0.4))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        return control.exists && control.isHittable
    }

    func assertAtlasDestinationVisible(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let destination = app.descendants(matching: .any)[identifier].firstMatch
        let visible = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in destination.exists && destination.isHittable },
            object: destination
        )
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 10), .completed, file: file, line: line)
    }

    func closeAtlasDestination(file: StaticString = #filePath, line: UInt = #line) {
        let done = app.buttons["cardio-atlas-destination-close"].firstMatch
        let share = app.descendants(matching: .any)["cardio-atlas-share-screen"].firstMatch
        // On compact Duo, scrolling the share preview can collapse the navigation
        // bar. Reveal its controls before asking XCTest to tap the modal's Done.
        if share.exists {
            for _ in 0..<3 where !done.exists || !done.isHittable {
                share.swipeDown()
            }
        }
        XCTAssertTrue(done.exists && done.isHittable, file: file, line: line)
        done.tap()
        assertAtlasDestinationVisible("exercise-session-detail-scroll", file: file, line: line)
    }

    func assertAtlasShareFitsWidth(file: StaticString = #filePath, line: UInt = #line) {
        let viewport = app.descendants(matching: .any)["cardio-atlas-share-screen"].firstMatch.frame
        for identifier in ["cardio-atlas-share-preview", "style-cardio-atlas-atlas",
                           "style-cardio-atlas-paceRibbon", "style-cardio-atlas-signature"] {
            let frame = app.descendants(matching: .any)[identifier].firstMatch.frame
            XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX - 1, identifier, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX + 1, identifier, file: file, line: line)
        }
    }

    func visibleAtlasShareControl(
        _ identifier: String,
        direction: ScrollDirection = .up,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let control = app.descendants(matching: .any)[identifier].firstMatch
        let scroll = app.descendants(matching: .any)["cardio-atlas-share-screen"].firstMatch
        for _ in 0..<8 {
            if control.exists && control.isHittable { return control }
            switch direction {
            case .up: scroll.swipeUp()
            case .down: scroll.swipeDown()
            }
        }
        XCTFail("Share control is not visible: \(identifier)", file: file, line: line)
        return control
    }
}
