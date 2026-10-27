@preconcurrency import XCTest

/// Seeded H01 reading order, independent routes, and design-map captures.
@MainActor
final class WellnessFlowUITests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "wellness" }

    override var additionalLaunchArguments: [String] {
        ["-morningBriefingDisabled", "YES",
         "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
         "--ui-test-theme", "desertWarm", "--ui-test-style", "light",
         "--ui-design-map-sleep-prediction", "--ui-visual-posture-fixtures"]
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func reveal(_ id: String, direction: ScrollDirection = .up) -> XCUIElement {
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(id, maxSwipes: 16, direction: direction), "\(id) should be reachable")
        let target = element(id)
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<10 {
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
                .insetBy(dx: 8, dy: 60)
            if viewport.contains(CGPoint(x: target.frame.midX, y: target.frame.midY)) { break }
            if target.frame.midY > viewport.midY {
                scroll.swipeUp(velocity: .slow)
            } else {
                scroll.swipeDown(velocity: .slow)
            }
        }
        return target
    }

    func testSeededReadingOrderAndEvidence() {
        navigateToWellness()
        let hero = waitForElement("wellness-hero-score", timeout: 15)
        let ring = waitForElement("wellness-hero-ring", timeout: 10)
        let evidence = waitForElement("wellness-hero-evidence", timeout: 10)
        XCTAssertEqual(waitForElement("wellness-hero-heading").label, "WELLNESS")
        XCTAssertEqual(ring.frame.width, 104, accuracy: 1)
        XCTAssertEqual(ring.frame.height, ring.frame.width, accuracy: 1)
        XCTAssertTrue(hero.label.contains("Wellness score"))
        XCTAssertTrue(evidence.exists)
        for (key, title) in [("sleep", "Sleep"), ("condition", "Condition"), ("body", "Body"), ("posture", "Posture")] {
            let row = waitForElement("wellness-hero-component-\(key)", timeout: 5)
            XCTAssertTrue(row.label.contains(title), "\(title) should have its own score evidence row")
            XCTAssertTrue(row.label.range(of: #"\d{1,3}"#, options: .regularExpression) != nil,
                          "\(title) should expose a measured score: \(row.label)")
        }

        let sleep = waitForElement("wellness-sleep-summary-card", timeout: 10)
        let prediction = waitForElement("wellness-sleep-prediction-card", timeout: 10)
        let injury = waitForElement("wellness-link-injuryhistory", timeout: 10)
        let health = waitForElement("wellness-section-health-indicators", timeout: 10)
        let body = waitForElement("wellness-link-bodyhistory", timeout: 10)
        let posture = waitForElement("wellness-link-posturehistory", timeout: 10)
        XCTAssertGreaterThan(sleep.frame.minY, hero.frame.minY)
        if prediction.frame.minX > sleep.frame.minX + 80 {
            XCTAssertLessThan(abs(sleep.frame.minY - prediction.frame.minY), 40,
                              "Wide layout should pair observed and predicted sleep")
        } else {
            XCTAssertGreaterThan(prediction.frame.minY, sleep.frame.minY,
                                 "Narrow layout should place prediction after observed sleep")
        }
        XCTAssertGreaterThan(injury.frame.minY, prediction.frame.minY)
        XCTAssertGreaterThan(health.frame.minY, injury.frame.minY)
        XCTAssertGreaterThan(body.frame.minY, injury.frame.minY)
        XCTAssertGreaterThan(posture.frame.minY, body.frame.minY)
        XCTAssertFalse(element("wellness-card-sleep").exists, "Sleep should not repeat in health indicators")
        XCTAssertTrue(element("wellness-card-hrv").exists)
    }

    func testSleepAndPredictionOpenIndependentDetails() {
        navigateToWellness()
        reveal("wellness-hero-sleep").tap()
        XCTAssertTrue(waitForElement(AXID.metricDetailScreen("sleep"), timeout: 10).exists)
        launchApp()
        navigateToWellness()
        reveal("wellness-sleep-prediction-detail-link").tap()
        XCTAssertTrue(waitForElement("wellness-sleep-prediction-detail-screen", timeout: 10).exists)
    }

    func testPredictionVisualScoreConfidenceAndFactors() {
        for (score, confidence, label, style) in [
            (37, "low", "Low Confidence", "dark"),
            (78, "medium", "Medium Confidence", "light"),
            (0, "low", "Low Confidence", "light"),
            (100, "high", "High Confidence", "light")
        ] {
            var configuration = launchConfiguration
            configuration.additionalEnvironment["DUNE_UI_SLEEP_PREDICTION_SCORE"] = String(score)
            configuration.additionalEnvironment["DUNE_UI_SLEEP_PREDICTION_CONFIDENCE"] = confidence
            if let index = configuration.additionalArguments.firstIndex(of: "--ui-test-style") {
                configuration.additionalArguments[index + 1] = style
            }
            launchApp(with: configuration)
            navigateToWellness()
            alignPredictionHeaderForCapture()
            let value = waitForElement("wellness-prediction-score-value")
            XCTAssertEqual(value.label, String(score))
            let meter = waitForElement("wellness-prediction-score-meter")
            XCTAssertEqual(meter.value as? String, "\(score) / 100")
            let badge = waitForElement("wellness-prediction-confidence")
            XCTAssertTrue(badge.label.contains(label))
            XCTAssertTrue(value.isHittable)
            XCTAssertTrue(meter.isHittable)
            XCTAssertTrue(badge.isHittable)
            addScreenshotAttachment(named: "H01-prediction-\(score)-\(confidence)-\(style)")
            let factors = reveal("wellness-prediction-factors-disclosure")
            factors.tap()
            XCTAssertTrue(app.staticTexts["Recent sleep has been consistent"].waitForExistence(timeout: 5))
            factors.tap()
            XCTAssertFalse(app.staticTexts["Recent sleep has been consistent"].exists)
        }
    }

    func testPredictionMaximumAXAndEmptyState() {
        var configuration = launchConfiguration
        configuration.additionalEnvironment["DUNE_UI_SLEEP_PREDICTION_SCORE"] = "37"
        configuration.additionalEnvironment["DUNE_UI_SLEEP_PREDICTION_CONFIDENCE"] = "low"
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToWellness()
        alignPredictionHeaderForCapture()
        XCTAssertEqual(waitForElement("wellness-prediction-score-value").label, "37")
        addScreenshotAttachment(named: "H01-prediction-37-MaxAX-score")
        let badge = reveal("wellness-prediction-confidence")
        XCTAssertTrue(badge.label.contains("Low Confidence"))
        XCTAssertTrue(badge.isHittable)
        // A hittable midpoint can leave the second line behind the floating tab bar.
        let window = app.windows.firstMatch.frame
        let top = max(window.minY, app.navigationBars.firstMatch.frame.maxY)
        let bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : window.maxY
        let viewport = CGRect(x: window.minX, y: top + 16, width: window.width, height: bottom - top - 32)
        for _ in 0..<4 {
            if viewport.contains(badge.frame) { break }
            let offset = max(-220, min(220, badge.frame.midY - viewport.midY))
            let start = app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -offset)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        XCTAssertTrue(viewport.contains(badge.frame),
                      "The entire confidence badge should be visible above the tab bar")
        addScreenshotAttachment(named: "H01-prediction-37-MaxAX-confidence")

        configuration = launchConfiguration
        configuration.additionalEnvironment["DUNE_UI_SLEEP_PREDICTION_SCORE"] = "none"
        launchApp(with: configuration)
        navigateToWellness()
        alignPredictionHeaderForCapture()
        XCTAssertFalse(element("wellness-prediction-score-meter").exists)
        XCTAssertFalse(element("wellness-prediction-confidence").exists)
        XCTAssertTrue(app.staticTexts["Sleep a few nights to see your sleep quality prediction."].exists)
        addScreenshotAttachment(named: "H01-prediction-empty")
    }

    private func alignPredictionHeaderForCapture() {
        let header = waitForElement("wellness-sleep-prediction-card", timeout: 15)
        let scroll = app.scrollViews.firstMatch
        let desiredY = max(app.navigationBars.firstMatch.frame.maxY, scroll.frame.minY) + 20
        for _ in 0..<8 {
            let offset = header.frame.minY - desiredY
            if abs(offset) < 16 { break }
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(
                CGVector(dx: 0, dy: -max(-240, min(240, offset)))
            ))
        }
    }

    func testSparseSleepBarsKeepCalendarPositionsAndWidth() {
        for (count, slots) in [(1, [6]), (2, [2, 6]), (4, [0, 3, 5, 6]), (7, Array(0..<7))] {
            var configuration = launchConfiguration
            configuration.additionalEnvironment["DUNE_UI_SLEEP_SAMPLE_COUNT"] = String(count)
            launchApp(with: configuration)
            navigateToWellness()
            reveal("wellness-sleep-bar-6")
            let bars = slots.map { waitForElement("wellness-sleep-bar-\($0)", timeout: 10) }
            for index in 0..<7 {
                XCTAssertEqual(element("wellness-sleep-bar-\(index)").exists, slots.contains(index),
                               "Missing dates must remain empty: count=\(count), slot=\(index)")
            }
            for bar in bars {
                XCTAssertEqual(bar.frame.width, 16, accuracy: 0.5)
                XCTAssertLessThanOrEqual(bar.frame.height, 64.5)
                XCTAssertTrue(bar.isHittable)
            }
            if bars.count > 1 {
                let slotWidth = (bars.last!.frame.midX - bars.first!.frame.midX) /
                    CGFloat(slots.last! - slots.first!)
                for index in 1..<bars.count {
                    XCTAssertEqual(bars[index].frame.midX - bars[index - 1].frame.midX,
                                   CGFloat(slots[index] - slots[index - 1]) * slotWidth, accuracy: 1)
                }
            }
            XCTAssertEqual(element("wellness-sleep-average").exists, count >= 2)
            reveal("wellness-hero-sleep", direction: .down)
            addScreenshotAttachment(named: "H01-sleep-\(count)-records")
        }
    }

    func testSparseSleepDarkAndAccessibility() {
        for maximumAX in [false, true] {
            var configuration = launchConfiguration
            configuration.additionalEnvironment["DUNE_UI_SLEEP_SAMPLE_COUNT"] = "2"
            if let index = configuration.additionalArguments.firstIndex(of: "--ui-test-style") {
                configuration.additionalArguments[index + 1] = "dark"
            }
            if maximumAX {
                configuration.additionalArguments += [
                    "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
                ]
            }
            launchApp(with: configuration)
            navigateToWellness()
            reveal("wellness-sleep-bar-6")
            let viewport = app.scrollViews.firstMatch.frame.intersection(app.windows.firstMatch.frame)
            for slot in [2, 6] {
                let bar = waitForElement("wellness-sleep-bar-\(slot)", timeout: 10)
                XCTAssertEqual(bar.frame.width, 16, accuracy: 0.5)
                XCTAssertTrue(viewport.contains(bar.frame))
            }
            if maximumAX {
                let labels = [0, 3, 6].map { waitForElement("wellness-sleep-date-\($0)") }
                for label in labels {
                    XCTAssertFalse(label.label.contains("…"))
                    XCTAssertTrue(viewport.contains(label.frame))
                    XCTAssertTrue(label.isHittable)
                }
                XCTAssertLessThan(labels[0].frame.maxX, labels[1].frame.minX)
                XCTAssertLessThan(labels[1].frame.maxX, labels[2].frame.minX)
            } else {
                reveal("wellness-hero-sleep", direction: .down)
            }
            addScreenshotAttachment(named: "H01-sleep-2-records-\(maximumAX ? "MaxAX" : "dark")")
        }
    }

    func testNoSleepRecordsShowsEmptyState() {
        var configuration = launchConfiguration
        configuration.additionalEnvironment["DUNE_UI_SLEEP_SAMPLE_COUNT"] = "0"
        launchApp(with: configuration)
        navigateToWellness()
        XCTAssertTrue(reveal("wellness-sleep-empty-state").isHittable)
        XCTAssertFalse(element("wellness-sleep-bar-6").exists)
        XCTAssertFalse(element("wellness-sleep-average").exists)
        addScreenshotAttachment(named: "H01-sleep-0-records")
    }

    func testBodyMeasurementsAndHeaderEdge() {
        navigateToWellness()
        let body = reveal("wellness-link-bodyhistory")
        // Frame coordinates can round a 44pt control down by a fraction of a pixel.
        XCTAssertGreaterThanOrEqual(body.frame.height, 43.5)
        for category in ["weight", "bodyFat", "leanBodyMass", "bmi"] {
            let card = waitForElement("wellness-card-\(category)", timeout: 10)
            XCTAssertTrue(card.staticTexts["Previous measurement"].exists,
                          "\(category) should show a real prior measurement")
        }
        XCTAssertTrue(reveal("wellness-add-body-record").isHittable)
        reveal("wellness-link-bodyhistory")
            .coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(waitForElement("body-history-detail-screen", timeout: 10).exists)
    }

    func testBodyWithoutPriorMeasurementsKeepsLatestValues() {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-test-no-body-comparison")
        launchApp(with: configuration)
        navigateToWellness()

        let latestValues = [
            (category: "weight", value: "78.3"),
            (category: "bodyFat", value: "17.8"),
            (category: "leanBodyMass", value: "63.1"),
            (category: "bmi", value: "24.7")
        ]
        for item in latestValues {
            let card = waitForElement("wellness-card-\(item.category)", timeout: 10)
            let currentValue = card.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@", item.value)
            ).firstMatch
            XCTAssertTrue(currentValue.exists || card.label.contains(item.value),
                          "\(item.category) should retain its measured latest value \(item.value)")
            XCTAssertFalse(card.staticTexts["Previous measurement"].exists,
                           "\(item.category) should not imply a comparison without a prior observation")
        }
    }

    func testRecordedPostureAndInjuryRemainReachableWithoutHealthData() {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-test-wellness-records-only")
        launchApp(with: configuration)
        navigateToWellness()

        XCTAssertTrue(reveal("wellness-link-injuryhistory").isHittable,
                      "A seeded injury should remain visible when HealthKit is empty")
        XCTAssertFalse(element("wellness-card-hrv").exists)
        XCTAssertFalse(element("wellness-card-weight").exists)
        XCTAssertTrue(reveal("wellness-add-body-record").isHittable,
                      "The empty body card should still offer manual entry")
        let score = reveal("wellness-posture-score")
        XCTAssertTrue(Int(score.label) != nil, "The actual seeded photo assessment score should remain visible")
        XCTAssertTrue(reveal("wellness-button-posture-capture").isHittable)
        reveal("wellness-link-posturehistory").tap()
        XCTAssertTrue(waitForElement("posture-history-screen", timeout: 10).exists)
    }

    func testPostureHistoryAndActionsRemainIndependent() {
        navigateToWellness()
        XCTAssertTrue(reveal("wellness-button-posture-capture").isHittable)
        XCTAssertTrue(reveal("wellness-button-posture-realtime").isHittable)
        XCTAssertTrue(element("wellness-posture-score").exists)
        reveal("wellness-link-posturehistory").tap()
        XCTAssertTrue(waitForElement("posture-history-screen", timeout: 10).exists)
    }

    func testMaximumAccessibilityValueFrames() {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToWellness()
        XCTAssertTrue(waitForElement("wellness-hero-score", timeout: 15).exists)
        XCTAssertFalse(element("wellness-hero-ring").exists,
                       "Accessibility sizes should use an external score instead of a fixed ring")
        for id in ["wellness-hero-external-score", "wellness-sleep-latest", "wellness-posture-score"] {
            let value = reveal(id)
            let viewport = app.scrollViews.firstMatch.frame.intersection(app.windows.firstMatch.frame)
            XCTAssertGreaterThan(value.frame.width, 0)
            XCTAssertGreaterThan(value.frame.height, 0)
            XCTAssertTrue(viewport.insetBy(dx: -1, dy: -1).contains(value.frame),
                          "\(id) should fit entirely in the scrolling viewport at maximum text size")
        }
        let weight = reveal("wellness-card-weight", direction: .down)
        let number = weight.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", #"^[0-9][0-9.,]*$"#)
        ).firstMatch
        XCTAssertTrue(number.exists, "Weight should expose its numeric value")
        XCTAssertGreaterThan(number.frame.width, 0)
        XCTAssertGreaterThan(number.frame.height, 0)
    }

    func testCaptureH01LightFlow() {
        captureH01Flow(suffix: "light")
    }

    func testCaptureHealthIndicatorDetails() {
        for style in ["light", "dark"] {
            var configuration = launchConfiguration
            if let index = configuration.additionalArguments.firstIndex(of: "--ui-test-style") {
                configuration.additionalArguments[index + 1] = style
            }
            launchApp(with: configuration)
            navigateToWellness()
            let metric = reveal("wellness-card-hrv")
            let scroll = app.scrollViews.firstMatch
            // Align the actual metric row below navigation, rather than capturing
            // a section heading while its chart remains behind the tab bar.
            let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
            let desiredY = max(viewport.minY + 180, app.navigationBars.firstMatch.frame.maxY + 28)
            let offset = metric.frame.minY - desiredY
            if abs(offset) > 12 {
                let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -max(-240, min(240, offset)))))
            }
            XCTAssertTrue(metric.isHittable)
            XCTAssertTrue(element("wellness-card-wristTemperature")
                .staticTexts["Change from personal baseline"].waitForExistence(timeout: 5),
                "Wrist temperature must identify a change from the personal baseline")
            let name = "H01-Wellness-Flow-health-detail-\(style)"
            if VisualAudit.isEnabled {
                VisualAudit.capture(name)
            } else {
                addScreenshotAttachment(named: name)
            }
        }
    }

    func testCaptureWideBodyMeasurementFrames() throws {
        navigateToWellness()
        let window = app.windows.firstMatch.frame
        guard window.width >= 700, window.height >= 1000 else {
            throw XCTSkip("Requires a large viewport to inspect all four body tiles together.")
        }
        let header = waitForElement("wellness-link-bodyhistory", timeout: 10)
        let scroll = app.scrollViews.firstMatch
        let desiredY = app.navigationBars.firstMatch.frame.maxY + 24
        for _ in 0..<10 {
            let offset = header.frame.minY - desiredY
            if abs(offset) < 24 { break }
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -max(-240, min(240, offset)))))
        }
        let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: -1, dy: -1)
        for category in ["weight", "bodyFat", "leanBodyMass", "bmi"] {
            let card = waitForElement("wellness-card-\(category)", timeout: 5)
            XCTAssertTrue(viewport.contains(card.frame), "Wide layout should show the complete \(category) tile")
        }
        if VisualAudit.isEnabled {
            VisualAudit.capture("H01-Wellness-Flow-body-detail-light")
        } else {
            addScreenshotAttachment(named: "H01-Wellness-Flow-body-detail-light")
        }
    }

    func testCaptureH01DarkFlow() {
        var configuration = launchConfiguration
        if let style = configuration.additionalArguments.firstIndex(of: "--ui-test-style") {
            configuration.additionalArguments[style + 1] = "dark"
        }
        launchApp(with: configuration)
        captureH01Flow(suffix: "dark")
    }

    func testCaptureOceanHeroFlow() {
        var configuration = launchConfiguration
        if let index = configuration.additionalArguments.firstIndex(of: "--ui-test-theme") {
            configuration.additionalArguments[index + 1] = "oceanCool"
        }
        launchApp(with: configuration)
        navigateToWellness()
        XCTAssertTrue(waitForElement("wellness-hero-ring", timeout: 10).exists)
        if VisualAudit.isEnabled {
            VisualAudit.capture("H01-Wellness-Flow-hero-Ocean")
        } else {
            addScreenshotAttachment(named: "H01-Wellness-Flow-hero-Ocean")
        }
    }

    func testCaptureH01MaximumAXFlow() {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        captureH01Flow(suffix: "MaxAX")
    }

    private func captureH01Flow(suffix: String) {
        navigateToWellness()
        let stops: [(String, String)] = [
            ("wellness-hero-score", "hero"),
            ("wellness-sleep-summary-card", "sleep"),
            ("wellness-sleep-prediction-card", "prediction"),
            ("wellness-link-injuryhistory", "injury"),
            ("wellness-section-health-indicators", "health"),
            ("wellness-link-bodyhistory", "body"),
            ("wellness-link-posturehistory", "posture"),
            ("wellness-button-posture-capture", "posture-actions")
        ]
        for (id, section) in stops {
            let target = reveal(id)
            XCTAssertGreaterThan(target.frame.height, 0)
            let name = "H01-Wellness-Flow-\(section)-\(suffix)"
            if VisualAudit.isEnabled {
                VisualAudit.capture(name)
            } else {
                addScreenshotAttachment(named: name)
            }
        }
    }
}
