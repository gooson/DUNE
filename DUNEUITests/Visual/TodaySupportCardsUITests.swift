import XCTest

/// Captures and checks the three support cards below the Today hero.
@MainActor
final class TodaySupportCardsUITests: SeededUITestBaseCase {
    func testDesertTodayProgressAtMaximumAccessibilityTextSize() throws {
        guard !app.isIPadLayout else { throw XCTSkip("Compact-width Today layout requires iPhone") }

        var configuration = launchConfiguration
        configuration.initialTabSelectionArgument = "today"
        configuration.additionalArguments += [
            "--ui-test-theme", "desertWarm",
            "--ui-test-style", "dark",
            "--ui-dashboard-hour", "12",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-morningBriefingDisabled", "YES"
        ]
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15), "Accessibility Today navigation should load")

        let scroll = app.scrollViews["dashboard-root-scroll"].firstMatch
        let progress = element("dashboard-daily-progress")
        let steps = element("dashboard-progress-steps")
        let sleep = element("dashboard-progress-sleep")
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertTrue(steps.waitForExistence(timeout: 5))
        XCTAssertTrue(sleep.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(sleep.frame.minY, steps.frame.maxY - 2,
                                    "Accessibility progress tiles should stack without overlap")
        assertWithin(steps, parent: progress, context: "Accessibility steps")
        assertWithin(sleep, parent: progress, context: "Accessibility sleep")

        let window = app.windows.firstMatch.frame
        for (tile, nameID, goalID) in [
            (steps, "dashboard-progress-steps-name", "dashboard-progress-steps-goal"),
            (sleep, "dashboard-progress-sleep-name", "dashboard-progress-sleep-goal")
        ] {
            XCTAssertGreaterThanOrEqual(tile.frame.minX, window.minX - 2,
                                        "\(tile.identifier): leading edge should fit the screen")
            XCTAssertLessThanOrEqual(tile.frame.maxX, window.maxX + 2,
                                     "\(tile.identifier): trailing edge should fit the screen")
            for identifier in [nameID, goalID] {
                let text = element(identifier)
                XCTAssertTrue(text.waitForExistence(timeout: 5), "\(identifier) should load")
                XCTAssertFalse(text.label.isEmpty, "\(identifier) should be readable")
                XCTAssertGreaterThan(text.frame.height, 0, "\(identifier) should have visible height")
                assertWithin(text, parent: tile, context: identifier)
            }
        }

        XCTAssertTrue(scrollFullyIntoViewport(steps, in: scroll), "Accessibility steps should be visible")
        addScreenshotAttachment(named: "Today Support Accessibility Progress")
        XCTAssertTrue(scrollFullyIntoViewport(sleep, in: scroll), "Accessibility sleep should be visible")
        addScreenshotAttachment(named: "Today Support Accessibility Sleep")
    }

    func testDesertTodaySupportCardsAtBothAppearances() {
        for style in ["Light", "Dark"] {
            var configuration = launchConfiguration
            configuration.initialTabSelectionArgument = "today"
            configuration.additionalArguments += [
                "--ui-test-theme", "desertWarm",
                "--ui-test-style", style.lowercased(),
                "--ui-dashboard-hour", "12",
                "-morningBriefingDisabled", "YES"
            ]
            launchApp(with: configuration)
            XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15), "\(style): Today navigation should load")

            let scroll = app.scrollViews["dashboard-root-scroll"].firstMatch
            XCTAssertTrue(scroll.waitForExistence(timeout: 10), "\(style): Today scroll view should load")

            let progress = element("dashboard-daily-progress")
            let steps = element("dashboard-progress-steps")
            let sleep = element("dashboard-progress-sleep")
            let stepsName = element("dashboard-progress-steps-name")
            let stepsGoal = element("dashboard-progress-steps-goal")
            let sleepName = element("dashboard-progress-sleep-name")
            let sleepGoal = element("dashboard-progress-sleep-goal")
            XCTAssertTrue(progress.waitForExistence(timeout: 10), "\(style): daily progress should load")
            XCTAssertTrue(steps.waitForExistence(timeout: 5), "\(style): steps tile should load")
            XCTAssertTrue(sleep.waitForExistence(timeout: 5), "\(style): sleep tile should load")
            for text in [stepsName, stepsGoal, sleepName, sleepGoal] {
                XCTAssertTrue(text.waitForExistence(timeout: 5), "\(style): \(text.identifier) should load")
                XCTAssertFalse(text.label.isEmpty, "\(style): \(text.identifier) should be readable")
            }
            XCTAssertTrue(scrollFullyIntoViewport(progress, in: scroll), "\(style): daily progress should fit in the viewport")
            assertWithin(steps, parent: progress, context: "\(style) steps")
            assertWithin(sleep, parent: progress, context: "\(style) sleep")
            for (text, tile) in [(stepsName, steps), (stepsGoal, steps), (sleepName, sleep), (sleepGoal, sleep)] {
                assertWithin(text, parent: tile, context: "\(style) \(text.identifier)")
                XCTAssertGreaterThan(text.frame.height, 0, "\(style): \(text.identifier) should not be clipped")
            }
            XCTAssertLessThanOrEqual(abs(steps.frame.width - sleep.frame.width), 2,
                                     "\(style): steps and sleep tiles should have equal widths")
            XCTAssertLessThanOrEqual(abs(steps.frame.minY - sleep.frame.minY), 2,
                                     "\(style): progress tiles should share a row")
            XCTAssertGreaterThanOrEqual(sleep.frame.minX, steps.frame.maxX - 2,
                                        "\(style): progress tiles should not overlap")
            addScreenshotAttachment(named: "Today Support \(style) Progress")

            let brief = element("dashboard-today-brief-card")
            if brief.exists {
                XCTAssertTrue(brief.frame.width > 0, "\(style): Today's Brief should have a visible frame")
                assertSameHorizontalEdges(brief, progress, context: "\(style) Today's Brief")
            }

            let recovery = element("dashboard-recovery-sleep-card")
            let chart = element("dashboard-recovery-sleep-chart")
            let lastSleep = element("dashboard-recovery-last-sleep")
            let period = element("dashboard-recovery-sleep-period")
            XCTAssertTrue(recovery.waitForExistence(timeout: 10), "\(style): Recovery & Sleep should load")
            XCTAssertTrue(chart.waitForExistence(timeout: 5), "\(style): seeded seven-day chart should load")
            XCTAssertTrue(lastSleep.waitForExistence(timeout: 5), "\(style): last sleep should load")
            XCTAssertTrue(period.waitForExistence(timeout: 5), "\(style): sleep period should load")
            XCTAssertTrue(scrollFullyIntoViewport(recovery, in: scroll), "\(style): Recovery & Sleep should fit in the viewport")
            assertSameHorizontalEdges(recovery, progress, context: "\(style) Recovery & Sleep")
            for child in [chart, lastSleep, period] {
                assertWithin(child, parent: recovery, context: "\(style) \(child.identifier)")
            }
            XCTAssertGreaterThan(lastSleep.frame.height, 0, "\(style): last sleep must not be clipped")
            XCTAssertGreaterThan(period.frame.height, 0, "\(style): period label must not be clipped")
            addScreenshotAttachment(named: "Today Support \(style) Recovery")
        }
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func visibleViewport(for scroll: XCUIElement) -> CGRect {
        let window = app.windows.firstMatch.frame
        let navigationBar = app.navigationBars.firstMatch
        let tabBar = app.tabBars.firstMatch
        let top = max(scroll.frame.minY, window.minY,
                      navigationBar.exists ? navigationBar.frame.maxY : window.minY) + 4
        let bottom = min(scroll.frame.maxY, window.maxY,
                         tabBar.exists ? tabBar.frame.minY : window.maxY) - 4
        let left = max(scroll.frame.minX, window.minX)
        let right = min(scroll.frame.maxX, window.maxX)
        return CGRect(x: left, y: top, width: max(0, right - left), height: max(0, bottom - top))
    }

    private func scrollFullyIntoViewport(_ target: XCUIElement, in scroll: XCUIElement) -> Bool {
        guard app.scrollToHittableElementIfNeeded(target.identifier, maxSwipes: 12) else { return false }
        for _ in 0..<8 {
            let viewport = visibleViewport(for: scroll)
            let frame = target.frame
            if viewport.contains(frame) { return true }
            guard frame.height <= viewport.height else { return false }
            let movement = frame.maxY > viewport.maxY
                ? frame.maxY - viewport.maxY + 6
                : frame.minY - viewport.minY - 6
            let distance = min(abs(movement), scroll.frame.height * 0.3)
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(
                CGVector(dx: 0, dy: movement > 0 ? -distance : distance)
            ))
        }
        return visibleViewport(for: scroll).contains(target.frame)
    }

    private func assertWithin(_ child: XCUIElement, parent: XCUIElement, context: String) {
        XCTAssertTrue(parent.frame.insetBy(dx: -2, dy: -2).contains(child.frame),
                      "\(context): content should fit within its card")
    }

    private func assertSameHorizontalEdges(_ card: XCUIElement, _ other: XCUIElement, context: String) {
        XCTAssertEqual(card.frame.minX, other.frame.minX, accuracy: 2,
                       "\(context): cards should share a leading edge")
        XCTAssertEqual(card.frame.maxX, other.frame.maxX, accuracy: 2,
                       "\(context): cards should share a trailing edge")
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(card.frame.minX, window.minX - 2, "\(context): leading edge should fit")
        XCTAssertLessThanOrEqual(card.frame.maxX, window.maxX + 2, "\(context): trailing edge should fit")
    }
}
