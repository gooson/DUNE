@preconcurrency import XCTest

/// Native screenshots use the opt-in synthetic route and place fixtures.
@MainActor
final class CardioAtlasUITests: ActivityExerciseSeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "activity" }
    override var additionalLaunchArguments: [String] {
        ["--ui-cardio-atlas-fixture", "-morningBriefingDisabled", "YES"]
    }

    func testRecordedRouteDetailAndProgress() {
        openRecord("running")
        XCTAssertTrue(element("cardio-atlas-section").waitForExistence(timeout: 10))
        XCTAssertTrue(element("cardio-atlas-map").exists)
        atlasScreenshot(named: "Cardio Atlas recorded route detail")

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("cardio-atlas-journey", maxSwipes: 8))
        element("cardio-atlas-journey").tap()
        XCTAssertTrue(element("cardio-atlas-journey-detail").waitForExistence(timeout: 8))
        atlasScreenshot(named: "Cardio Atlas Journey progress")
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
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("cardio-atlas-passport", maxSwipes: 8))
        element("cardio-atlas-passport").tap()
        XCTAssertTrue(element("cardio-atlas-passport-detail").waitForExistence(timeout: 8))
        atlasScreenshot(named: "Cardio Atlas Passport progress")
    }

    func testShareStylesAndPrivateLocationDefault() {
        openRecord("running")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("cardio-atlas-share", maxSwipes: 8))
        element("cardio-atlas-share").tap()
        XCTAssertTrue(element("cardio-atlas-share-preview").waitForExistence(timeout: 10))
        let location = element("cardio-atlas-share-location")
        XCTAssertTrue(location.exists)
        XCTAssertEqual(location.value as? String, "0", "Location sharing should start off")
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        atlasScreenshot(named: "Cardio Atlas share private Atlas")

        location.tap()
        XCTAssertEqual(location.value as? String, "1")
        XCTAssertTrue(element("cardio-atlas-share-trim").exists)
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        atlasScreenshot(named: "Cardio Atlas share Atlas route")

        location.tap()
        XCTAssertEqual(location.value as? String, "0")
        XCTAssertTrue(element("cardio-atlas-share-map-image").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        atlasScreenshot(named: "Cardio Atlas location removed from shared image")
        location.tap()
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))

        let ribbon = element("style-cardio-atlas-paceRibbon")
        XCTAssertTrue(ribbon.exists && ribbon.isEnabled)
        ribbon.tap()
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        atlasScreenshot(named: "Cardio Atlas share Pace Ribbon")

        element("style-cardio-atlas-signature").tap()
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        atlasScreenshot(named: "Cardio Atlas share Signature")
    }

    func testIndoorPlacePickerCancelPreservesPlace() {
        openRecord("elliptical")
        XCTAssertTrue(element("cardio-atlas-map").waitForExistence(timeout: 10))
        atlasScreenshot(named: "Cardio Atlas indoor place")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("cardio-atlas-place", maxSwipes: 8))
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
        app.buttons[AXID.activityRecentSeeAll].firstMatch.tap()
        XCTAssertTrue(element(AXID.exerciseViewScreen).waitForExistence(timeout: 10))
        let rowID = "exercise-row-\(definitionID)"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(rowID, maxSwipes: 8))
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
    override var initialTabSelectionArgument: String? { "activity" }
    override var additionalLaunchArguments: [String] {
        ["--ui-cardio-atlas-fixture", "-morningBriefingDisabled", "YES",
         "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
         "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    }

    func testKoreanLargeTextDetailAndPassport() {
        openRecord("running")
        XCTAssertTrue(element("cardio-atlas-section").waitForExistence(timeout: 10))
        atlasScreenshot(named: "Cardio Atlas Korean large text detail")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("cardio-atlas-passport", maxSwipes: 10))
        element("cardio-atlas-passport").tap()
        XCTAssertTrue(element("cardio-atlas-passport-detail").waitForExistence(timeout: 8))
        atlasScreenshot(named: "Cardio Atlas Korean large text Passport")
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
        app.buttons[AXID.activityRecentSeeAll].firstMatch.tap()
        XCTAssertTrue(element(AXID.exerciseViewScreen).waitForExistence(timeout: 10))
        let rowID = "exercise-row-\(definitionID)"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(rowID, maxSwipes: 8))
        element(rowID).tap()
        XCTAssertTrue(element("exercise-session-detail-scroll").waitForExistence(timeout: 8))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
