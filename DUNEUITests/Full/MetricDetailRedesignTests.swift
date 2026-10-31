@preconcurrency import XCTest

/// T06 before/after capture contract. The matrix runs in one test invocation;
/// DUNE_T06_METRIC selects one key for focused diagnosis.
@MainActor
final class MetricDetailRedesignTests: SeededUITestBaseCase {
    nonisolated private var selectedKey: String {
        ProcessInfo.processInfo.environment["DUNE_T06_METRIC"] ?? "hrv"
    }

    override var additionalLaunchArguments: [String] {
        [
            "--ui-t06-metric", selectedKey,
            "--ui-disable-animations",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US", "-morningBriefingDisabled", "YES"
        ]
    }

    func testSelectedMetricIdentityAndCapture() throws {
        guard let expected = Self.matrix[selectedKey] else {
            XCTFail("Unknown T06 matrix key: \(selectedKey)")
            return
        }
        assertIdentityAndCapture(key: selectedKey, expected: expected)
    }

    /// Records the frozen original UI's normalization, not correctness in meters.
    func testOriginalSwimmingMeterInputLegacyUnitAndCapture() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments = [
            "--ui-t06-metric", "exercise-m", "--ui-disable-animations",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-morningBriefingDisabled", "YES"
        ]
        launchApp(with: configuration)
        let screen = app.descendants(matching: .any)["metric-detail-screen-exercise"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 15))
        let loading = app.progressIndicators.firstMatch
        _ = loading.waitForExistence(timeout: 1)
        XCTAssertTrue(loading.waitForNonExistence(timeout: 15))
        XCTAssertTrue(app.navigationBars["Swimming"].firstMatch.waitForExistence(timeout: 5))
        let header = app.descendants(matching: .any)["metric-summary-header"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        // Old loadExerciseData replaces the incoming m with min for this seeded
        // Swimming fixture. Preserve and label the actual old result explicitly.
        XCTAssertEqual(header.label, "Exercise, 1,314 min")
        XCTAssertTrue(app.buttons["metric-detail-show-all-data"].firstMatch.exists)
        XCTContext.runActivity(named: "Original Swimming input and rendered unit") { activity in
            let note = XCTAttachment(string: "Synthetic input: Swimming, 1314 m; original rendered header: \(header.label)")
            note.lifetime = .keepAlways
            activity.add(note)
        }
        addScreenshotAttachment(named: "T06-original-swimming-input-1314m-rendered-min")
        VisualAudit.capture("Original Swimming input 1314 m; rendered 1,314 min")
    }

    func testAllMetricIdentitiesAndCaptures() throws {
        // Budget is declared before the first matrix launch, not raised after a timeout.
        executionTimeAllowance = 600
        for key in Self.matrixOrder {
            guard let expected = Self.matrix[key] else {
                XCTFail("Missing T06 matrix contract for \(key)")
                return
            }
            var configuration = launchConfiguration
            configuration.additionalArguments = [
                "--ui-t06-metric", key,
                "--ui-disable-animations",
                "-AppleLanguages", "(en)",
                "-AppleLocale", "en_US", "-morningBriefingDisabled", "YES"
            ]
            // --ui-reset and --seed-mock are retained by launchConfiguration.
            // A new AUT launch prevents navigation, scroll, and fixture carryover.
            launchApp(with: configuration)
            assertIdentityAndCapture(key: key, expected: expected)
        }
    }

    private func assertIdentityAndCapture(key: String, expected: Expected) {
        let screen = app.descendants(matching: .any)["metric-detail-screen-\(expected.category)"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 15), "\(key) must open its original metric detail")

        // MetricDetailView's loading overlay is a sibling of its ScrollView AXID.
        // Give the task a chance to present it, then require it to leave the app.
        let loading = app.progressIndicators.firstMatch
        _ = loading.waitForExistence(timeout: 1)
        XCTAssertTrue(loading.waitForNonExistence(timeout: 15), "\(key) must finish loading before identity and capture")

        // The original summary is one combined accessibility element. Assert its
        // category-specific value and unit before accepting any image as evidence.
        let summary = app.descendants(matching: .any)["metric-summary-header"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "\(key) original metric header must exist")
        let label = summary.label
        XCTAssertTrue(label.contains(expected.title), "Expected \(key) title \(expected.title), got \(label)")
        XCTAssertTrue(label.contains(expected.value), "Expected \(key) value \(expected.value), got \(label)")
        if !expected.unit.isEmpty {
            XCTAssertTrue(label.contains(expected.unit), "Expected \(key) unit \(expected.unit), got \(label)")
        }
        XCTAssertTrue(app.buttons["metric-detail-show-all-data"].waitForExistence(timeout: 10), "\(key) All Data route must remain")
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 10), "\(key) time period control must remain")

        attach("T06-\(key)-initial")
        if key == "sleep" {
            for section in ["quality", "patterns", "nocturnal", "external"] {
                XCTAssertTrue(app.descendants(matching: .any)["sleep-section-\(section)"].firstMatch.exists,
                              "Sleep must preserve \(section) analysis")
            }
        }
        screen.swipeUp()
        attach("T06-\(key)-lower")
    }

    func testHRVRealWellnessEntryAndAllData() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments = ["--ui-disable-animations", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-morningBriefingDisabled", "YES"]
        configuration.initialTabSelectionArgument = "wellness"
        launchApp(with: configuration)
        navigateToWellness()
        XCTAssertTrue(app.scrollToElementIfNeeded("wellness-card-hrv", maxSwipes: 6))
        app.descendants(matching: .any)["wellness-card-hrv"].firstMatch.tap()

        XCTAssertTrue(app.descendants(matching: .any)["metric-detail-screen-hrv"].firstMatch.waitForExistence(timeout: 10))
        attach("T06-hrv-real-wellness-entry")
        let allDataButton = app.buttons["metric-detail-show-all-data"]
        XCTAssertTrue(allDataButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("metric-detail-show-all-data", maxSwipes: 12),
                      "HRV All Data button must be reachable by scrolling")
        allDataButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["all-data-screen-hrv"].firstMatch.waitForExistence(timeout: 10))
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private struct Expected {
        let category: String
        let title: String
        let value: String
        let unit: String
    }

    private static let matrix: [String: Expected] = [
        "hrv": .init(category: "hrv", title: "Heart Rate Variability", value: "75", unit: "ms"),
        "rhr": .init(category: "rhr", title: "Resting Heart Rate", value: "52", unit: "bpm"),
        "heartRate": .init(category: "heartRate", title: "Heart Rate", value: "72", unit: "bpm"),
        "sleep": .init(category: "sleep", title: "Sleep", value: "7h 54min", unit: ""),
        "exercise-min": .init(category: "exercise", title: "Exercise", value: "42", unit: "min"),
        "exercise-km": .init(category: "exercise", title: "Exercise", value: "10.2", unit: "km"),
        "steps": .init(category: "steps", title: "Steps", value: "8,200", unit: "steps"),
        "weight": .init(category: "weight", title: "Weight", value: "78.4", unit: "kg"),
        "bmi": .init(category: "bmi", title: "BMI", value: "24.7", unit: ""),
        "bodyFat": .init(category: "bodyFat", title: "Body Fat", value: "17.8", unit: "%"),
        "leanBodyMass": .init(category: "leanBodyMass", title: "Lean Body Mass", value: "63.1", unit: "kg"),
        "spo2": .init(category: "spo2", title: "Blood Oxygen", value: "98", unit: "%"),
        "respiratoryRate": .init(category: "respiratoryRate", title: "Respiratory Rate", value: "15", unit: "breaths/min"),
        "vo2Max": .init(category: "vo2Max", title: "VO2 Max", value: "44.7", unit: "ml/kg/min"),
        "heartRateRecovery": .init(category: "heartRateRecovery", title: "HR Recovery", value: "24", unit: "bpm"),
        "wristTemperature": .init(category: "wristTemperature", title: "Wrist Temp", value: "-0.3", unit: "°C"),
        "breathingDisturbances": .init(category: "breathingDisturbances", title: "Breathing Disturbances", value: "1.2", unit: "/hr")
    ]

    private static let matrixOrder = [
        "hrv", "rhr", "heartRate", "sleep", "exercise-min", "exercise-km",
        "steps", "weight", "bmi", "bodyFat", "leanBodyMass", "spo2",
        "respiratoryRate", "vo2Max", "heartRateRecovery", "wristTemperature",
        "breathingDisturbances"
    ]
}
