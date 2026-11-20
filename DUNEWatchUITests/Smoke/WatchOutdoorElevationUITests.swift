import XCTest

@MainActor
final class WatchOutdoorElevationUITests: WatchUITestBaseCase {
    override var uiScenario: LaunchScenario? { .responsiveLayout }
    override var additionalLaunchArguments: [String] {
        ["--ui-watch-direct-outdoor-running", "--ui-watch-outdoor-elevation"]
    }

    func testOutdoorElevationUsesMeasuredFixture() {
        XCTAssertTrue(elementExists("watch-running-distance-metrics", timeout: 10))
        for _ in 0..<3 { app.swipeLeft() }
        XCTAssertTrue(elementExists("watch-cardio-secondary", timeout: 5))
        let chart = app.descendants(matching: .any)["watch-outdoor-elevation-chart"].firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        XCTAssertTrue((chart.value as? String)?.contains("48") == true,
                      "The chart should announce measured ascent")
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "watch-design-map-C04-outdoor-elevation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testUnavailableAltitudeHasNoGraph() {
        var configuration = launchConfiguration
        configuration.additionalArguments.removeAll { $0 == "--ui-watch-outdoor-elevation" }
        launchApp(with: configuration)
        XCTAssertTrue(elementExists("watch-running-distance-metrics", timeout: 10))
        for _ in 0..<3 { app.swipeLeft() }
        XCTAssertTrue(elementExists("watch-outdoor-elevation-unavailable", timeout: 5))
        XCTAssertFalse(elementExists("watch-outdoor-elevation-chart", timeout: 1))
        addScreenshotAttachment(named: "watch-design-map-C04-outdoor-elevation-unavailable")
    }
}
