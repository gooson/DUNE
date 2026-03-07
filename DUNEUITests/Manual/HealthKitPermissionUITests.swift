import XCTest

/// UI test that launches the app and auto-accepts HealthKit permission dialogs.
/// Run this test once on a fresh simulator before running unit tests to ensure
/// HealthKit authorization is granted. Without this, HealthKit queries in unit tests
/// may fail with authorization errors.
///
/// Usage:
///   xcodebuild test -project Dailve/Dailve.xcodeproj -scheme DailveUITests \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2' \
///     -only-testing DailveUITests/HealthKitPermissionUITests
@MainActor
final class HealthKitPermissionUITests: XCTestCase {

    var app: XCUIApplication!
    private static let manualRunEnvKey = "RUN_HEALTHKIT_PERMISSION_UI_TEST"

    private static var shouldRunManualPermissionFlow: Bool {
        let env = ProcessInfo.processInfo.environment[manualRunEnvKey] == "1"
        let args = ProcessInfo.processInfo.arguments
        return env || args.contains("--run-healthkit-permission-uitest")
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard Self.shouldRunManualPermissionFlow else {
            throw XCTSkip("Manual-only test. Set \(Self.manualRunEnvKey)=1 to run.")
        }
        continueAfterFailure = true
        app = XCUIApplication()
        // Keep UI test mode explicit while still allowing real HealthKit authorization flow.
        app.launchArguments = ["--healthkit-permission-uitest"]
        app.launch()
    }

    /// Automatically handles HealthKit and other system permission dialogs.
    /// The interruption monitor intercepts system alerts (HealthKit auth sheet,
    /// notification permission, etc.) and taps the appropriate accept button.
    func testGrantHealthKitPermission() throws {
        // Register interruption monitor for system alerts
        addUIInterruptionMonitor(withDescription: "System Permission Alert") { alert in
            // HealthKit authorization sheet has "Allow" button
            let allowButton = alert.buttons["Allow"]
            if allowButton.exists {
                allowButton.tap()
                return true
            }

            // Some permission dialogs use "OK"
            let okButton = alert.buttons["OK"]
            if okButton.exists {
                okButton.tap()
                return true
            }

            // Notification permission
            let dontAllowButton = alert.buttons["Don't Allow"]
            if dontAllowButton.exists {
                dontAllowButton.tap()
                return true
            }

            return false
        }

        handleCloudSyncConsentIfNeeded()
        handleHealthKitSheetIfNeeded()
        dismissNotificationAlertIfNeeded()
        handleAutomaticWhatsNewIfNeeded()

        // Verify app is still running
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    private func handleCloudSyncConsentIfNeeded() {
        let keepLocalOnlyButton = app.descendants(matching: .any)["cloud-sync-consent-local-button"].firstMatch
        if keepLocalOnlyButton.waitForExistence(timeout: 5) {
            keepLocalOnlyButton.tap()
        }
    }

    private func handleHealthKitSheetIfNeeded() {
        app.tap() // Trigger interruption monitor delivery.

        let healthKitSheet = app.navigationBars["Health Access"]
        guard healthKitSheet.waitForExistence(timeout: 5) else { return }

        let turnOnAll = app.switches["Turn On All"]
        if turnOnAll.exists {
            turnOnAll.tap()
        }

        let allow = app.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }
    }

    private func dismissNotificationAlertIfNeeded() {
        app.tap() // Trigger interruption monitor delivery.

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "Don't Allow", "OK"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 2) {
                button.tap()
                return
            }
        }
    }

    private func handleAutomaticWhatsNewIfNeeded() {
        let whatsNewScreen = app.descendants(matching: .any)["whatsnew-screen"].firstMatch
        guard whatsNewScreen.waitForExistence(timeout: 5) else { return }

        let closeButton = app.buttons["whatsnew-close-button"].firstMatch
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
        }
    }
}
