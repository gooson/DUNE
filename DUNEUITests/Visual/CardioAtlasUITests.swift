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
        addScreenshotAttachment(named: "Cardio Atlas recorded route detail")

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("cardio-atlas-journey", maxSwipes: 8))
        element("cardio-atlas-journey").tap()
        XCTAssertTrue(element("cardio-atlas-journey-detail").waitForExistence(timeout: 8))
        addScreenshotAttachment(named: "Cardio Atlas Journey progress")
    }

    func testPassportFromRecordedRoute() {
        openRecord("running")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("cardio-atlas-passport", maxSwipes: 8))
        element("cardio-atlas-passport").tap()
        XCTAssertTrue(element("cardio-atlas-passport-detail").waitForExistence(timeout: 8))
        addScreenshotAttachment(named: "Cardio Atlas Passport progress")
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
        addScreenshotAttachment(named: "Cardio Atlas share private Atlas")

        location.tap()
        XCTAssertEqual(location.value as? String, "1")
        XCTAssertTrue(element("cardio-atlas-share-trim").exists)
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        addScreenshotAttachment(named: "Cardio Atlas share Atlas route")

        let ribbon = element("style-cardio-atlas-paceRibbon")
        XCTAssertTrue(ribbon.exists && ribbon.isEnabled)
        ribbon.tap()
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        addScreenshotAttachment(named: "Cardio Atlas share Pace Ribbon")

        element("style-cardio-atlas-signature").tap()
        XCTAssertTrue(element("cardio-atlas-share-action").waitForExistence(timeout: 10))
        addScreenshotAttachment(named: "Cardio Atlas share Signature")
    }

    func testIndoorPlacePickerCancelPreservesPlace() {
        openRecord("elliptical")
        XCTAssertTrue(element("cardio-atlas-map").waitForExistence(timeout: 10))
        addScreenshotAttachment(named: "Cardio Atlas indoor place")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("cardio-atlas-place", maxSwipes: 8))
        element("cardio-atlas-place").tap()
        XCTAssertTrue(element("cardio-atlas-place-cancel").waitForExistence(timeout: 8))
        XCTAssertTrue(element("cardio-atlas-place-remove").exists)
        addScreenshotAttachment(named: "Cardio Atlas selected place editor")
        element("cardio-atlas-place-cancel").tap()
        XCTAssertTrue(element("cardio-atlas-map").waitForExistence(timeout: 8))
    }

    func testUnlocatedCardioShowsActualEmptyState() {
        openRecord("rowing-machine")
        XCTAssertTrue(element("cardio-atlas-map").waitForExistence(timeout: 10))
        XCTAssertTrue(element("cardio-atlas-map-empty").exists)
        addScreenshotAttachment(named: "Cardio Atlas location not recorded")
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
