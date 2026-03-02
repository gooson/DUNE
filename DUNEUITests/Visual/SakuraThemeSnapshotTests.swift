import XCTest

/// Visual regression capture for Sakura theme in light/dark appearance.
/// Captures full-screen Today tab screenshots as XCTest attachments.
@MainActor
final class SakuraThemeSnapshotTests: XCTestCase {
    private enum SnapshotStyle: String {
        case light
        case dark
    }

    func testTodaySakuraLightSnapshot() throws {
        let app = launchSakuraApp(style: .light)
        defer {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 2)
        }
        captureTodaySnapshot(from: app, name: "Sakura Today Light")
    }

    func testTodaySakuraDarkSnapshot() throws {
        let app = launchSakuraApp(style: .dark)
        defer {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 2)
        }
        captureTodaySnapshot(from: app, name: "Sakura Today Dark")
    }

    // MARK: - Helpers

    private func launchSakuraApp(style: SnapshotStyle) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-theme", "sakuraCalm",
            "--ui-test-style", style.rawValue
        ]

        app.terminate()
        app.launch()
        let tabBarExists = app.tabBars.firstMatch.waitForExistence(timeout: 10)
        let todayTabExists = app.buttons["tab-today"].firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(tabBarExists || todayTabExists, "Primary navigation should be available after launch")
        return app
    }

    private func captureTodaySnapshot(from app: XCUIApplication, name: String) {
        let tabBarToday = app.tabBars.buttons["Today"].firstMatch
        if tabBarToday.waitForExistence(timeout: 3) {
            tabBarToday.tap()
        } else {
            let fallbackToday = app.buttons["tab-today"].firstMatch
            if fallbackToday.waitForExistence(timeout: 3) {
                fallbackToday.tap()
            }
        }

        let settingsButton = app.descendants(matching: .any)[AXID.dashboardToolbarSettings].firstMatch
        _ = settingsButton.waitForExistence(timeout: 8)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
