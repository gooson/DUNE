@preconcurrency import XCTest

/// Native T07 before/after contract. Each matrix entry starts a fresh seeded app.
@MainActor
final class AllDataDetailRedesignTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "today" }

    override var additionalLaunchArguments: [String] {
        routeArguments(for: "hrv")
    }

    func testAllCategoryReadyRowsAndCaptures() {
        executionTimeAllowance = 600
        for fixture in Self.readyFixtures {
            launch(category: fixture.category)
            let screen = allDataScreen(for: fixture.category)
            XCTAssertTrue(screen.waitForExistence(timeout: 15), "Missing \(fixture.category) destination")
            XCTAssertTrue(todaySection(in: screen, daysAgo: fixture.daysAgo).waitForExistence(timeout: 15),
                          "Missing \(fixture.category) reporting-date section")
            let row = row(containing: fixture.value, in: screen)
            XCTAssertTrue(row.waitForExistence(timeout: 15),
                          "Missing \(fixture.category) time/value row: \(fixture.value)")
            XCTAssertTrue(Self.hasTimePrefix(row.label),
                          "\(fixture.category) row must combine a localized time and \(fixture.value): \(row.label)")
            XCTAssertFalse(screen.descendants(matching: .any)["all-data-empty-state"].firstMatch.exists)
            addScreenshotAttachment(named: "T07-\(fixture.category)-native")
        }
    }

    func testSleepUsesReportingDateAndActualStageTime() {
        launch(category: "sleep")
        let screen = allDataScreen(for: "sleep")
        XCTAssertTrue(screen.waitForExistence(timeout: 15))
        XCTAssertTrue(todaySection(in: screen, daysAgo: 0).waitForExistence(timeout: 15))
        let row = row(containing: "7h 46min", in: screen)
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        let stageStart = Calendar.current.date(byAdding: .hour, value: 1,
                                               to: Calendar.current.startOfDay(for: Date()))!
        let expectedTime = stageStart.formatted(
            .dateTime.hour().minute().locale(Locale(identifier: "en_US"))
        )
        XCTAssertTrue(row.label.contains(expectedTime),
                      "Sleep time must use the first non-awake stage, not the reporting-day midnight: \(row.label)")
        addScreenshotAttachment(named: "T07-sleep-reporting-day-native")
    }

    func testLimitedReadyAndLimitedEmptyStates() {
        launch(category: "hrv", extra: ["--uitest-limited-health-history"])
        var screen = allDataScreen(for: "hrv")
        XCTAssertTrue(screen.waitForExistence(timeout: 15))
        XCTAssertTrue(notice(in: screen).waitForExistence(timeout: 15))
        XCTAssertTrue(row(containing: "75 ms", in: screen).waitForExistence(timeout: 15))
        XCTAssertFalse(screen.descendants(matching: .any)["all-data-empty-state"].firstMatch.exists)
        addScreenshotAttachment(named: "T07-hrv-limited-ready-native")

        launch(category: "hrv", extra: ["--uitest-limited-health-history", "--ui-test-wellness-records-only"])
        screen = allDataScreen(for: "hrv")
        XCTAssertTrue(screen.waitForExistence(timeout: 15))
        XCTAssertTrue(notice(in: screen).waitForExistence(timeout: 15))
        XCTAssertTrue(screen.descendants(matching: .any)["all-data-empty-state"].firstMatch
            .waitForExistence(timeout: 15))
        XCTAssertTrue(screen.staticTexts["No data in the available range."].firstMatch.exists)
        addScreenshotAttachment(named: "T07-hrv-limited-empty-native")
    }

    func testEmptyHistoryAndBreathingReadyState() {
        launch(category: "breathingDisturbances", extra: ["--ui-test-wellness-records-only"])
        var screen = allDataScreen(for: "breathingDisturbances")
        XCTAssertTrue(screen.waitForExistence(timeout: 15))
        XCTAssertTrue(screen.descendants(matching: .any)["all-data-empty-state"].firstMatch
            .waitForExistence(timeout: 15))
        XCTAssertTrue(screen.staticTexts["No data available yet."].firstMatch.exists)
        addScreenshotAttachment(named: "T07-breathingDisturbances-empty-native")

        launch(category: "breathingDisturbances")
        screen = allDataScreen(for: "breathingDisturbances")
        XCTAssertTrue(screen.waitForExistence(timeout: 15))
        XCTAssertTrue(todaySection(in: screen, daysAgo: 0).waitForExistence(timeout: 15))
        XCTAssertTrue(row(containing: "1.2/hr", in: screen).waitForExistence(timeout: 15))
        addScreenshotAttachment(named: "T07-breathingDisturbances-ready-native")
    }

    func testDarkMaximumAccessibilityBaselineCapture() {
        launch(category: "wristTemperature", extra: [
            "--ui-test-style", "dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        let screen = allDataScreen(for: "wristTemperature")
        XCTAssertTrue(screen.waitForExistence(timeout: 15))
        XCTAssertTrue(todaySection(in: screen, daysAgo: 0).waitForExistence(timeout: 15))
        let row = row(containing: "+36.5 °C", in: screen)
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("all-data-screen-wristTemperature", maxSwipes: 8))
        XCTAssertTrue(row.isHittable, "The seeded temperature row should remain available to accessibility; pixel reflow is assessed from baseline capture")
        addScreenshotAttachment(named: "T07-wristTemperature-dark-maximum-AX-native")
    }

    private func launch(category: String, extra: [String] = []) {
        var configuration = launchConfiguration
        configuration.additionalArguments = routeArguments(for: category) + extra
        launchApp(with: configuration)
    }

    private func routeArguments(for category: String) -> [String] {
        ["--ui-t07-all-data", category, "--ui-disable-animations",
         "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
         "-morningBriefingDisabled", "YES"]
    }

    private func allDataScreen(for category: String) -> XCUIElement {
        app.descendants(matching: .any)["all-data-screen-\(category)"].firstMatch
    }

    private func todaySection(in screen: XCUIElement, daysAgo: Int) -> XCUIElement {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let sectionTitle = date.formatted(
            .dateTime.year().month(.wide).day().locale(Locale(identifier: "en_US"))
        )
        return screen.staticTexts.matching(NSPredicate(format: "label ==[c] %@", sectionTitle)).firstMatch
    }

    private func row(containing value: String, in screen: XCUIElement) -> XCUIElement {
        let escapedValue = NSRegularExpression.escapedPattern(for: value)
        return screen.descendants(matching: .any)
            .matching(NSPredicate(format: "label MATCHES %@",
                                  "^[0-9]{1,2}:[0-9]{2}\\s*(AM|PM),\\s*.*\(escapedValue).*$"))
            .firstMatch
    }

    private func notice(in screen: XCUIElement) -> XCUIElement {
        screen.descendants(matching: .any)["limited-health-history-notice"].firstMatch
    }

    nonisolated private static func hasTimePrefix(_ label: String) -> Bool {
        label.range(of: #"^\d{1,2}:\d{2}\s*(AM|PM),\s*"#, options: .regularExpression) != nil
    }

    private struct ReadyFixture {
        let category: String
        let value: String
        var daysAgo = 0
    }

    private static let readyFixtures: [ReadyFixture] = [
        .init(category: "hrv", value: "75 ms"),
        .init(category: "rhr", value: "50 bpm"),
        .init(category: "heartRate", value: "67 bpm"),
        .init(category: "sleep", value: "7h 46min"),
        .init(category: "exercise", value: "48 min", daysAgo: 1),
        .init(category: "steps", value: "8,200"),
        .init(category: "weight", value: "78.3 kg"),
        .init(category: "bmi", value: "24.7"),
        .init(category: "bodyFat", value: "17.8%"),
        .init(category: "leanBodyMass", value: "63.1 kg"),
        .init(category: "spo2", value: "98%"),
        .init(category: "respiratoryRate", value: "14 breaths/min"),
        .init(category: "vo2Max", value: "48.4 ml/kg/min"),
        .init(category: "heartRateRecovery", value: "31 bpm"),
        .init(category: "wristTemperature", value: "+36.5 °C"),
        .init(category: "breathingDisturbances", value: "1.2/hr")
    ]
}
