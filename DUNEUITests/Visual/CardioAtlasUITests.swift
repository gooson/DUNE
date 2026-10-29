@preconcurrency import XCTest

/// Native screenshots use the opt-in synthetic route and place fixtures.
@MainActor
final class CardioAtlasUITests: ActivityExerciseSeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-cardio-atlas-fixture", "-morningBriefingDisabled", "YES"]
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

    private func atlasScreenshot(named name: String) {
        addScreenshotAttachment(named: name)
        if ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_HOST_ONLY"] == "1" {
            VisualAudit.capture(name)
        }
    }

    private func openRecord(_ definitionID: String) {
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

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
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

    private func atlasScreenshot(named name: String) {
        addScreenshotAttachment(named: name)
        if ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_HOST_ONLY"] == "1" {
            VisualAudit.capture(name)
        }
    }

    private func openRecord(_ definitionID: String) {
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

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}

@MainActor
private extension UITestBaseCase {
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
