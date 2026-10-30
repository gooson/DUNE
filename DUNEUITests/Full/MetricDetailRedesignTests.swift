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

        // The current quantity hero is one combined accessibility element. Assert its
        // category-specific value and unit before accepting any image as evidence.
        let summary = app.descendants(matching: .any)["metric-summary-header"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "\(key) quantity hero must exist")
        let label = summary.label
        XCTAssertTrue(label.contains(expected.title), "Expected \(key) title \(expected.title), got \(label)")
        XCTAssertTrue(label.contains(expected.value), "Expected \(key) value \(expected.value), got \(label)")
        if !expected.unit.isEmpty {
            XCTAssertTrue(label.contains(expected.unit), "Expected \(key) unit \(expected.unit), got \(label)")
        }
        let updatedValue = summary.value as? String ?? ""
        XCTAssertTrue(updatedValue.hasPrefix("Updated ") && updatedValue.count > "Updated ".count,
                      "\(key) must expose a nonempty measurement date to accessibility")
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

    func testHRVIntegratedHistoryPagesAndKeepsStatistics() throws {
        XCTAssertTrue(app.descendants(matching: .any)["metric-detail-screen-hrv"].firstMatch.waitForExistence(timeout: 15))
        let range = app.staticTexts["detail-chart-visible-range"].firstMatch
        let stats = app.descendants(matching: .any)["detail-chart-visible-summary"].firstMatch
        let previous = app.buttons["detail-chart-previous-period"]
        let next = app.buttons["detail-chart-next-period"]
        XCTAssertTrue(range.waitForExistence(timeout: 10))
        XCTAssertTrue(stats.waitForExistence(timeout: 10))
        XCTAssertTrue(previous.waitForExistence(timeout: 10))
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        let current = range.label
        XCTAssertFalse(next.isEnabled)
        previous.tap()
        XCTAssertNotEqual(range.label, current)
        XCTAssertTrue(next.isEnabled)
        next.tap()
        XCTAssertEqual(range.label, current)
        XCTAssertTrue(app.buttons["metric-detail-show-all-data"].exists)
    }

    func testHRVPeriodSegmentsUpdateVisibleSummary() throws {
        XCTAssertTrue(app.descendants(matching: .any)["metric-detail-screen-hrv"].firstMatch.waitForExistence(timeout: 15))
        let period = app.segmentedControls.firstMatch
        let range = app.staticTexts["detail-chart-visible-range"].firstMatch
        let basis = app.staticTexts["detail-chart-summary-basis"].firstMatch
        let average = app.descendants(matching: .any)["detail-chart-summary-average"].firstMatch
        let minimum = app.descendants(matching: .any)["detail-chart-summary-minimum"].firstMatch
        let maximum = app.descendants(matching: .any)["detail-chart-summary-maximum"].firstMatch
        XCTAssertTrue(period.waitForExistence(timeout: 10))
        XCTAssertTrue(range.waitForExistence(timeout: 10))
        var previousRange = range.label

        for (title, expectedBasis) in [
            ("D", "Hourly averages"), ("W", "Daily averages"),
            ("M", "Daily averages"), ("6M", "Weekly averages"),
            ("Y", "Monthly averages")
        ] {
            let option = period.buttons[title]
            XCTAssertTrue(option.exists, "Missing \(title) period")
            option.tap()
            XCTAssertTrue(option.isSelected, "\(title) period should be selected")
            XCTAssertTrue(waitForLabelChange(of: range, from: previousRange),
                          "\(title) must publish its own visible range")
            XCTAssertTrue(waitForLabel(basis, equalTo: expectedBasis),
                          "\(title) must publish the source cadence")
            for stat in [average, minimum, maximum] {
                XCTAssertTrue(waitForPopulatedStat(stat),
                              "\(title) must publish visible Avg/Min/Max instead of a loading placeholder")
            }
            previousRange = range.label
        }
    }

    func testBodyUnsupportedPeerStates() throws {
        for key in ["bodyFat", "leanBodyMass"] {
            var configuration = launchConfiguration
            configuration.additionalArguments = [
                "--ui-t06-metric", key, "--ui-disable-animations",
                "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-morningBriefingDisabled", "YES"
            ]
            launchApp(with: configuration)
            XCTAssertTrue(app.descendants(matching: .any)["metric-detail-screen-\(key)"].firstMatch.waitForExistence(timeout: 15))
            XCTAssertTrue(app.scrollToHittableElementIfNeeded("body-peer-card", maxSwipes: 8))
            XCTAssertTrue(app.staticTexts["A comparable survey mean is not available for this measure."].firstMatch.exists)
            XCTAssertFalse(app.buttons["body-peer-criteria-cta"].exists,
                           "\(key) must not offer an unsupported comparison cohort")
            XCTAssertFalse(app.buttons["body-peer-source"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["body-peer-reference"].firstMatch.exists)
            XCTAssertFalse(app.descendants(matching: .any)["body-peer-difference"].firstMatch.exists)
            attach("T06-\(key)-unsupported-peer")
        }
    }

    func testHRVDarkDetailReadability() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments = [
            "--ui-t06-metric", "hrv", "--ui-test-style", "dark",
            "--ui-disable-animations", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-morningBriefingDisabled", "YES"
        ]
        launchApp(with: configuration)
        let screen = app.descendants(matching: .any)["metric-detail-screen-hrv"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 15))
        let hero = app.descendants(matching: .any)["metric-summary-header"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(hero.label.contains("75") && hero.label.contains("ms"))
        let updatedValue = hero.value as? String ?? ""
        XCTAssertTrue(updatedValue.hasPrefix("Updated ") && updatedValue.count > "Updated ".count)
        attach("T06-hrv-dark-hero")
        XCTAssertTrue(revealWholeDetailRow("detail-chart-visible-range", in: screen),
                      "Dark history range must fit inside the visible scroll viewport")
        attach("T06-hrv-dark-history")
    }

    func testWeightMaximumAccessibilitySizeKeepsContentReachable() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments = [
            "--ui-t06-metric", "weight", "--ui-disable-animations",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-morningBriefingDisabled", "YES"
        ]
        launchApp(with: configuration)
        let screen = app.descendants(matching: .any)["metric-detail-screen-weight"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 15))
        let hero = app.descendants(matching: .any)["metric-summary-header"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(hero.label.contains("78.4") && hero.label.contains("kg"))
        let updatedValue = hero.value as? String ?? ""
        XCTAssertTrue(updatedValue.hasPrefix("Updated ") && updatedValue.count > "Updated ".count)
        attach("T06-weight-maximum-AX-hero")

        for id in ["detail-chart-visible-range", "detail-chart-summary-average"] {
            XCTAssertTrue(revealWholeDetailRow(id, in: screen),
                          "\(id) must fit inside the visible scroll viewport at maximum accessibility size")
            attach("T06-weight-maximum-AX-\(id)")
        }
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("body-peer-criteria-cta", maxSwipes: 10))
        attach("T06-weight-maximum-AX-peer-entry")
    }

    func testWeightPeerCriteriaCancelApplyAndSource() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments = [
            "--ui-t06-metric", "weight", "--ui-disable-animations",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-morningBriefingDisabled", "YES"
        ]
        launchApp(with: configuration)
        XCTAssertTrue(app.descendants(matching: .any)["metric-detail-screen-weight"].firstMatch.waitForExistence(timeout: 15))
        let criteria = app.buttons["body-peer-criteria-cta"]
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("body-peer-criteria-cta", maxSwipes: 8))
        criteria.tap()
        XCTAssertFalse(app.buttons["body-peer-apply"].isEnabled)
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["body-peer-reference"].firstMatch.exists)
        criteria.tap()
        let age = app.buttons["body-peer-age-selection"].firstMatch
        let sex = app.buttons["body-peer-sex-selection"].firstMatch
        age.tap()
        app.buttons["30–39 years"].firstMatch.tap()
        sex.tap()
        app.buttons["Male (survey)"].firstMatch.tap()
        let apply = app.buttons["body-peer-apply"]
        XCTAssertTrue(apply.isEnabled)
        apply.tap()
        XCTAssertTrue(app.descendants(matching: .any)["body-peer-current"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["body-peer-reference"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["body-peer-difference"].firstMatch.exists)
        let source = app.buttons["body-peer-source"]
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("body-peer-source", maxSwipes: 4))
        source.tap()
        XCTAssertTrue(app.staticTexts["Survey source"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.links["Open free original report"].firstMatch.exists)
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

    /// Scrolls along the gutter so the chart cannot intercept the gesture.
    /// Checks a single row against the real viewport, not the oversized hero/card frame.
    private func revealWholeDetailRow(
        _ identifier: String, in scroll: XCUIElement, maxSwipes: Int = 10
    ) -> Bool {
        let row = app.descendants(matching: .any)[identifier].firstMatch
        guard scroll.waitForExistence(timeout: 5), row.waitForExistence(timeout: 5) else { return false }
        for _ in 0..<maxSwipes {
            let viewport = visibleDetailViewport(for: scroll)
            guard !viewport.isNull else { return false }
            if viewport.contains(row.frame) { return true }
            let moveUp = row.frame.midY > viewport.midY
            let startY: CGFloat = moveUp ? 0.75 : 0.25
            let endY: CGFloat = moveUp ? 0.25 : 0.75
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: startY))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.05, dy: endY)
                ), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        return visibleDetailViewport(for: scroll).contains(row.frame)
    }

    private func visibleDetailViewport(for scroll: XCUIElement) -> CGRect {
        let scrollFrame = scroll.frame.intersection(app.windows.firstMatch.frame)
        let navigationBar = app.navigationBars.firstMatch
        let tabBar = app.tabBars.firstMatch
        let top = max(scrollFrame.minY, navigationBar.exists ? navigationBar.frame.maxY : scrollFrame.minY)
        let hasBottomTabBar = tabBar.exists && tabBar.isHittable &&
            tabBar.frame.minY > app.windows.firstMatch.frame.midY
        let bottom = hasBottomTabBar ? min(scrollFrame.maxY, tabBar.frame.minY) : scrollFrame.maxY
        guard bottom > top + 8 else { return .null }
        return CGRect(x: scrollFrame.minX, y: top,
                      width: scrollFrame.width, height: bottom - top).insetBy(dx: 4, dy: 4)
    }

    private func waitForLabel(
        _ element: XCUIElement, equalTo expected: String, timeout: TimeInterval = 10
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expected), object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForLabelChange(
        of element: XCUIElement, from previous: String, timeout: TimeInterval = 10
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", previous), object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForPopulatedStat(_ element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@ AND NOT label CONTAINS %@", "ms", "—"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: 10) == .completed
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
        "exercise-m": .init(category: "exercise", title: "Exercise", value: "1,314", unit: "m"),
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
        "hrv", "rhr", "heartRate", "sleep", "exercise-min", "exercise-km", "exercise-m",
        "steps", "weight", "bmi", "bodyFat", "leanBodyMass", "spo2",
        "respiratoryRate", "vo2Max", "heartRateRecovery", "wristTemperature",
        "breathingDisturbances"
    ]
}
