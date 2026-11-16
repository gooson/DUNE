@preconcurrency import XCTest
import UIKit

/// Verifies the estimated-zone fallback for an imported simulator workout.
@MainActor
final class WorkoutZoneDetailUITests: ActivityExerciseSeededUITestBaseCase {
    private enum Fixture {
        static let workoutID = "mock-workout-running-tempo"
        static let notificationWorkoutID = "ui-test-activity-workout-running"
        static let zoneSection = "healthkit-workout-zones-section"
        static let zoneSource = "healthkit-workout-zones-source"
    }

    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testImportedWorkoutShowsEstimatedHeartRateZones() throws {
        // Arrange: the seeded imported workout has heart-rate samples but no
        // HealthKit zone group, so the app must show its estimated fallback.
        navigateToActivity()
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.activityRecentSeeAll, maxSwipes: 24),
            "Recent workouts should be reachable"
        )
        app.buttons[AXID.activityRecentSeeAll].firstMatch.auditTap()
        XCTAssertTrue(waitForElement(AXID.exerciseViewScreen, timeout: 10).exists)

        // Act: open the imported workout from the full exercise list.
        let rowID = AXID.exerciseRow(Fixture.workoutID)
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(rowID, maxSwipes: 12),
            "The seeded imported workout should appear in Exercise"
        )
        app.buttons[rowID].firstMatch.auditTap()
        XCTAssertTrue(waitForElement(AXID.healthkitWorkoutDetailScreen, timeout: 10).exists)

        // Assert: the fallback labels its source and exposes several zone rows.
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(Fixture.zoneSection, maxSwipes: 12),
            "Heart-rate zones should be visible in workout detail"
        )
        let source = app.staticTexts[Fixture.zoneSource].firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 10), "Zone source should be accessible")
        XCTAssertEqual(source.label, "Estimated zones")
        let method = app.staticTexts["healthkit-workout-zones-estimate-method"].firstMatch
        XCTAssertTrue(method.waitForExistence(timeout: 5), "Estimated zones should disclose their maximum heart rate")
        XCTAssertEqual(method.label, "Estimated using a 190 bpm maximum heart rate.")

        for index in 1...3 {
            let zone = app.descendants(matching: .any)["healthkit-workout-zone-\(index)"].firstMatch
            XCTAssertTrue(zone.waitForExistence(timeout: 5), "Zone \(index) should be present")
            XCTAssertTrue(zone.label.contains("bpm"), "Zone \(index) should expose its heart-rate range")
        }
        addScreenshotAttachment(named: defaultArtifactName(suffix: "estimated-heart-rate-zones"))
    }

    func testImportedWorkoutLastCardClearsBottomTabs() throws {
        try assertLastCardSpacing(maximumText: false)
    }

    func testImportedWorkoutLastCardClearsBottomTabsAtMaximumText() throws {
        try assertLastCardSpacing(maximumText: true)
    }

    private func assertLastCardSpacing(maximumText: Bool) throws {
        if maximumText {
            var configuration = launchConfiguration
            configuration.additionalArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ]
            launchApp(with: configuration)
        }

        // The notification route pushes within the active tab, keeping the
        // floating tab bar visible. This fixture's final card is Weather.
        navigateToDashboard()
        let notifications = app.buttons[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(notifications.waitForExistence(timeout: 10) && notifications.isHittable)
        notifications.auditTap()
        let hub = app.collectionViews[AXID.notificationHubScreen].firstMatch
        XCTAssertTrue(hub.waitForExistence(timeout: 10))
        let row = app.buttons[AXID.notificationWorkoutRow(Fixture.notificationWorkoutID)].firstMatch
        for _ in 0..<16 where !(row.exists && row.isHittable) {
            hub.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(row.exists && row.isHittable)
        row.auditTap()

        let detail = app.scrollViews[AXID.healthkitWorkoutDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        let lastCard = app.otherElements["healthkit-workout-weather-section"].firstMatch
        XCTAssertTrue(lastCard.waitForExistence(timeout: 10))

        // Swipe until the last card stops moving, so the assertion measures the
        // scroll end rather than an intermediate position.
        var reachedBottom = false
        for _ in 0..<16 {
            let previousBottom = lastCard.frame.maxY
            detail.swipeUp(velocity: .slow)
            if abs(lastCard.frame.maxY - previousBottom) < 1 {
                reachedBottom = true
                break
            }
        }
        XCTAssertTrue(reachedBottom, "Workout detail should reach its scroll end")

        let cardFrame = lastCard.frame
        let windowFrame = app.windows.firstMatch.frame
        XCTAssertGreaterThan(cardFrame.height, 0)
        XCTAssertTrue(cardFrame.intersects(detail.frame))
        XCTAssertLessThanOrEqual(cardFrame.maxY, windowFrame.maxY,
                                 "The final workout card should remain inside the window")

        let tabBar = app.tabBars.firstMatch
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertTrue(tabBar.waitForExistence(timeout: 5) && tabBar.isHittable,
                          "The iPhone regression must measure a visible bottom tab bar")
            XCTAssertGreaterThan(tabBar.frame.midY, windowFrame.midY)
        }
        if tabBar.exists && tabBar.frame.midY > windowFrame.midY {
            XCTAssertGreaterThanOrEqual(tabBar.frame.minY - cardFrame.maxY, 12,
                                        "The final workout card needs at least 12 pt above the bottom tab bar")
        }
        // iPad can place its tab bar above the content; its top edge is not a
        // bottom obstruction and must not be used for this spacing assertion.
        VisualAudit.capture("W28 \(maximumText ? "MAX" : "normal") imported workout bottom")
    }
}
