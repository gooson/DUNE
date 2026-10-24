@preconcurrency import XCTest

@MainActor
final class LaunchExperienceSmokeTests: UITestBaseCase {
    func testReleaseNewsAppearsInNotificationHubWithoutAutomaticSheet() throws {
        XCTAssertFalse(app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch.exists,
                       "Launch should not automatically present a release sheet")
        XCTAssertTrue(app.waitAndTap(AXID.dashboardToolbarNotifications), "Open notifications from Today")
        let filter = app.segmentedControls[AXID.notificationsFilter].firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        // Picker order is All, Health, News across localizations.
        let news = filter.buttons.element(boundBy: 2)
        XCTAssertTrue(news.waitForExistence(timeout: 5))
        news.tap()
        let release = app.buttons[AXID.notificationsNewsRelease].firstMatch
        XCTAssertTrue(release.waitForExistence(timeout: 5), "Release should appear in News")
        release.tap()

        let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "Release detail should open")

        let featureRowIDs = [
            AXID.whatsNewRow("healthDataQA"),
            AXID.whatsNewRow("widgets"),
            AXID.whatsNewRow("exerciseLogging"),
        ]
        let hasFeatureRow = featureRowIDs.contains { identifier in
            app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(hasFeatureRow, "Manual release detail should render at least one feature row")

        XCTAssertFalse(app.buttons["whatsnew-close-button"].exists,
                       "Manual release detail should use navigation back")
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Release detail should have a back button")
        back.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch.waitForExistence(timeout: 5),
                      "Back should return to the notification hub")
    }
}
