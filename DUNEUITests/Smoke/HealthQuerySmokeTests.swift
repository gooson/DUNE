@preconcurrency import XCTest

/// Exercises the real native query view with isolated, synthetic UI evidence.
@MainActor
final class HealthQuerySmokeTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "today" }

    override var additionalLaunchArguments: [String] {
        ["--ui-health-query-fixture", "-morningBriefingDisabled", "YES",
         "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testBrowseEntryPeriodSourceAndBack() {
        openBrowse()
        XCTAssertTrue(element("health-query-result-kind-latestWorkout").waitForExistence(timeout: 8))
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("health-query-source", maxSwipes: 8))
        XCTAssertTrue(element("health-query-source").exists, "A loaded answer should show its provenance")

        selectPeriod("last7Days")
        XCTAssertTrue(element("health-query-result-kind-latestWorkout").waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Period:")).firstMatch.exists)

        let done = app.buttons["health-query-done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertFalse(element("health-query-screen").waitForExistence(timeout: 2))
        XCTAssertTrue(element("health-qa-browse-records").waitForExistence(timeout: 5),
                      "Back navigation should restore the Q&A inspector")
    }

    func testNoDataIsExplicit() {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-health-query-no-data")
        launchApp(with: configuration)
        openBrowse()
        XCTAssertTrue(element("health-query-result").waitForExistence(timeout: 8))
        XCTAssertTrue(element("health-query-no-data").exists)
        XCTAssertFalse(element("health-query-source").exists)
        capture("SQ00-no-data")
    }

    /// One launch captures every supported information choice. The source metadata
    /// records that these are native simulator screens populated by a test fixture.
    func testCaptureAllQueryKinds() {
        openBrowse(captureEntry: true)
        let kinds = [
            "latestWorkout", "workoutSummary", "strengthSets", "personalRecord",
            "cardioDetail", "latestBody", "bodyTrend", "sleep", "condition",
            "metricComparison", "workoutComparison", "memoSearch", "report", "longAnalysis"
        ]
        for (index, kind) in kinds.enumerated() {
            if index > 0 { selectKind(kind) }
            if kind == "memoSearch" {
                let field = app.textFields["health-query-search-field"].firstMatch
                XCTAssertTrue(field.waitForExistence(timeout: 5), "Memo search requires an explicit query")
                field.tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5),
                              "The software keyboard must be active for text input")
                field.typeText("Sample")
                capture("SQ12-software-keyboard")
                let keyboardSearch = app.keyboards.buttons.matching(
                    NSPredicate(format: "label ==[c] %@", "search")
                ).firstMatch
                if keyboardSearch.isHittable {
                    keyboardSearch.tap()
                } else {
                    let submit = app.buttons["health-query-search-submit"].firstMatch
                    XCTAssertTrue(submit.waitForExistence(timeout: 5))
                    submit.tap()
                }
                XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5),
                              "Dismiss the software keyboard before the native capture")
            }
            XCTAssertTrue(element("health-query-result-kind-\(kind)").waitForExistence(timeout: 8),
                          "Loaded fixture should match \(kind)")
            XCTAssertTrue(element("health-query-source").exists, "Loaded \(kind) should name its source")
            capture(String(format: "SQ%02d-%@", index + 1, kind))
        }
    }

    func testReportPreviewShareCancel() {
        openBrowse()
        selectKind("report")
        XCTAssertTrue(element("health-query-result-kind-report").waitForExistence(timeout: 8))
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("health-query-preview-report", maxSwipes: 12))
        app.buttons["health-query-preview-report"].firstMatch.tap()
        XCTAssertTrue(element("health-query-report-preview").waitForExistence(timeout: 5))
        capture("SQ13-report-preview")

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("health-query-share", maxSwipes: 8))
        app.buttons["health-query-share"].firstMatch.tap()
        let shareSheet = app.otherElements["ActivityListView"].firstMatch
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 8), "System share sheet should open")
        let shareCaption = app.descendants(matching: .any)["LP.CaptionBar.BottomCaption"].firstMatch
        XCTAssertTrue(shareCaption.waitForExistence(timeout: 5))
        XCTAssertTrue(shareCaption.label.contains("Workout Report"), "The shared item should be the report")
        capture("SQ13-report-share")

        let dismissShare = app.buttons["header.closeButton"].firstMatch
        if dismissShare.exists && dismissShare.isHittable {
            dismissShare.tap()
        } else {
            let window = app.windows.firstMatch.frame
            let popover = shareSheet.frame
            let navigationBottom = max(
                app.navigationBars["Health information"].firstMatch.frame.maxY,
                app.buttons["health-query-done"].firstMatch.frame.maxY
            )
            let candidates = [
                CGPoint(x: window.midX, y: popover.minY - 24),
                CGPoint(x: popover.minX - 24, y: popover.midY),
                CGPoint(x: popover.maxX + 24, y: popover.midY)
            ]
            let safePoint = candidates.first {
                window.insetBy(dx: 12, dy: 12).contains($0)
                    && $0.y > navigationBottom + 12
                    && !popover.contains($0)
            }
            XCTAssertNotNil(safePoint, "Share popover should leave a safe dismissal point")
            if let safePoint {
                app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: safePoint.x - window.minX, dy: safePoint.y - window.minY))
                    .tap()
            }
        }
        XCTAssertTrue(shareSheet.waitForNonExistence(timeout: 5), "Cancelling should close the system share sheet")
        XCTAssertTrue(element("health-query-report-preview").waitForExistence(timeout: 5),
                      "Cancelling system share should return to the report")
    }

    func testCaptureBodyAndDurationAtMaximumTextSize() {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-test-theme", "desertWarm", "--ui-test-style", "dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        openBrowse()
        for (kind, captureName) in [("latestBody", "SQ06-accessibility-body"),
                                     ("latestWorkout", "SQ01-accessibility-duration")] {
            selectKind(kind)
            let value = element("health-query-hero-value")
            XCTAssertTrue(app.scrollToHittableElementIfNeeded("health-query-hero-value", maxSwipes: 10))
            for _ in 0..<4 where !app.windows.firstMatch.frame.contains(value.frame) {
                let upward = value.frame.maxY > app.windows.firstMatch.frame.maxY
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upward ? 0.7 : 0.4))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upward ? 0.5 : 0.6))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            XCTAssertTrue(app.windows.firstMatch.frame.contains(value.frame), "The large value must fit in the native viewport")
            capture(captureName)
        }
    }

    private func openBrowse(captureEntry: Bool = false) {
        navigateToDashboard()
        let cardID = "dashboard-health-qa-card"
        XCTAssertTrue(app.scrollToElementIfNeeded(cardID, maxSwipes: 18))
        let card = element(cardID)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let browse = element("health-qa-browse-records")
        XCTAssertTrue(browse.waitForExistence(timeout: 8))
        if captureEntry { capture("T17-health-qa-browse") }
        browse.tap()
        XCTAssertTrue(element("health-query-screen").waitForExistence(timeout: 8))
    }

    private func selectKind(_ kind: String) {
        let picker = element("health-query-kind")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("health-query-kind", maxSwipes: 8, direction: .down))
        picker.tap()
        let choice = app.buttons["health-query-kind-\(kind)"].firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "Information menu should offer \(kind)")
        choice.tap()
    }

    private func selectPeriod(_ period: String) {
        tapVisiblePicker("health-query-period")
        let choice = app.buttons["health-query-period-\(period)"].firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
    }

    private func tapVisiblePicker(_ id: String) {
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(id, maxSwipes: 8, direction: .down))
        let picker = element(id)
        let scrollView = app.scrollViews.containing(.button, identifier: id).firstMatch
        XCTAssertTrue(scrollView.exists, "\(id) should be in the query scroll view")

        for _ in 0..<4 {
            let viewport = scrollView.frame.intersection(app.windows.firstMatch.frame)
            let navigationBottom = max(
                app.navigationBars["Health information"].firstMatch.frame.maxY,
                app.buttons["health-query-done"].firstMatch.frame.maxY
            )
            let top = max(viewport.minY, navigationBottom) + 8
            let bottom = viewport.maxY - 16
            let pickerFrame = picker.frame
            if pickerFrame.minY >= top && pickerFrame.maxY <= bottom && picker.isHittable {
                picker.tap()
                return
            }

            let moveDown = pickerFrame.minY < top
            let distance = moveDown ? top - pickerFrame.minY + 20 : pickerFrame.maxY - bottom + 20
            let startY = moveDown ? top + 40 : bottom - 40
            let endY = moveDown ? min(bottom - 20, startY + distance)
                                : max(top + 20, startY - distance)
            let origin = scrollView.coordinate(withNormalizedOffset: .zero)
            let x = viewport.midX - scrollView.frame.minX
            origin.withOffset(CGVector(dx: x, dy: startY - scrollView.frame.minY))
                .press(forDuration: 0.05, thenDragTo:
                    origin.withOffset(CGVector(dx: x, dy: endY - scrollView.frame.minY)))
        }
        XCTFail("\(id) did not become fully visible below the navigation bar")
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func capture(_ name: String) {
        if ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_HOST_ONLY"] == "1" {
            VisualAudit.capture(name)
        } else {
            let started = Date()
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            let frame = app.windows.firstMatch.frame
            let metadata: [String: Any] = [
                "captureStartedAt": ISO8601DateFormatter().string(from: started),
                "captureFinishedAt": ISO8601DateFormatter().string(from: Date()),
                "viewportPoints": ["x": Double(frame.minX), "y": Double(frame.minY),
                                   "width": Double(frame.width), "height": Double(frame.height)],
                "orientation": XCUIDevice.shared.orientation.rawValue,
                "softwareKeyboardVisible": app.keyboards.firstMatch.exists,
                "dataKind": "synthetic DEBUG health-query fixture"
            ]
            if let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                let readback = XCTAttachment(string: text)
                readback.name = name + "-metadata"
                readback.lifetime = .keepAlways
                add(readback)
            }
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = name + "-hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
    }
}
