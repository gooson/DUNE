@preconcurrency import XCTest

@MainActor
final class LaunchExperienceSmokeTests: UITestBaseCase {
    override var additionalLaunchArguments: [String] { ["--force-automatic-whatsnew"] }

    func testAutomaticWhatsNewRendersFeatureRows() throws {
        let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "Automatic What's New sheet should appear on launch")

        let featureRowIDs = [
            AXID.whatsNewRow("healthDataQA"),
            AXID.whatsNewRow("widgets"),
            AXID.whatsNewRow("exerciseLogging"),
        ]
        let hasFeatureRow = featureRowIDs.contains { identifier in
            app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(hasFeatureRow, "Automatic What's New sheet should render at least one feature row")

        let closeButton = app.buttons["whatsnew-close-button"].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Automatic What's New close button should exist")
        closeButton.tap()
    }
}
