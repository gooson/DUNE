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
            XCTAssertTrue(brief.waitForExistence(timeout: 10), "\(style): seeded daytime brief should load")
            XCTAssertTrue(brief.frame.width > 0, "\(style): Today's Brief should have a visible frame")
            assertSameHorizontalEdges(brief, progress, context: "\(style) Today's Brief")

            let recovery = element("dashboard-recovery-sleep-card")
            let chart = element("dashboard-recovery-sleep-chart")
            let lastSleep = element("dashboard-recovery-last-sleep")
            let period = element("dashboard-recovery-sleep-period")
            let legend = element("dashboard-recovery-stage-legend")
            XCTAssertTrue(recovery.waitForExistence(timeout: 10), "\(style): Recovery & Sleep should load")
            XCTAssertTrue(chart.waitForExistence(timeout: 5), "\(style): seeded seven-day chart should load")
            XCTAssertTrue(lastSleep.waitForExistence(timeout: 5), "\(style): last sleep should load")
            XCTAssertTrue(period.waitForExistence(timeout: 5), "\(style): sleep period should load")
            XCTAssertTrue(legend.waitForExistence(timeout: 5), "\(style): sleep stages must have readable labels")
            XCTAssertTrue(scrollFullyIntoViewport(recovery, in: scroll), "\(style): Recovery & Sleep should fit in the viewport: card=\(recovery.frame), viewport=\(visibleViewport(for: scroll))")
            assertSameHorizontalEdges(recovery, progress, context: "\(style) Recovery & Sleep")
            for child in [chart, lastSleep, period, legend] {
                assertWithin(child, parent: recovery, context: "\(style) \(child.identifier)")
            }
            XCTAssertGreaterThan(lastSleep.frame.height, 0, "\(style): last sleep must not be clipped")
            XCTAssertGreaterThan(period.frame.height, 0, "\(style): period label must not be clipped")
            addScreenshotAttachment(named: "Today Support \(style) Recovery")
        }
    }

    /// The expanded Duo viewport is wide but too short to show the whole recovery card at once.
    func testDesertTodaySupportCardsInShortLandscapeViewport() {
        assertShortViewportSupportCards(landscape: true, label: "Landscape")
    }

    /// The folded Duo viewport can also be too short to show the whole recovery card at once.
    func testDesertTodaySupportCardsInShortPortraitViewport() {
        assertShortViewportSupportCards(landscape: false, label: "Portrait")
    }

    private func assertShortViewportSupportCards(landscape: Bool, label: String) {
        var configuration = launchConfiguration
        configuration.initialTabSelectionArgument = "today"
        configuration.additionalArguments += [
            "--ui-test-theme", "desertWarm",
            "--ui-test-style", "dark",
            "--ui-dashboard-hour", "12",
            "-morningBriefingDisabled", "YES"
        ]
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15), "\(label): Today navigation should load")

        let window = app.windows.firstMatch.frame
        if landscape {
            XCTAssertGreaterThan(window.width, window.height,
                                 "Landscape selector requires the expanded Duo viewport")
        } else {
            XCTAssertGreaterThan(window.height, window.width,
                                 "Portrait selector requires the folded Duo viewport")
        }
        XCTAssertLessThanOrEqual(window.height, 800,
                                 "\(label): this selector requires a short viewport")
        let scroll = app.scrollViews["dashboard-root-scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))

        let progress = element("dashboard-daily-progress")
        let steps = element("dashboard-progress-steps")
        let sleep = element("dashboard-progress-sleep")
        let stepsName = element("dashboard-progress-steps-name")
        let stepsGoal = element("dashboard-progress-steps-goal")
        let sleepName = element("dashboard-progress-sleep-name")
        let sleepGoal = element("dashboard-progress-sleep-goal")
        let brief = element("dashboard-today-brief-card")
        let recovery = element("dashboard-recovery-sleep-card")
        let lastSleep = element("dashboard-recovery-last-sleep")
        let period = element("dashboard-recovery-sleep-period")
        let chart = element("dashboard-recovery-sleep-chart")
        let legend = element("dashboard-recovery-stage-legend")
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        for item in [steps, sleep, stepsName, stepsGoal, sleepName, sleepGoal] {
            XCTAssertTrue(item.waitForExistence(timeout: 5), "\(label): \(item.identifier) should load")
        }
        XCTAssertTrue(brief.waitForExistence(timeout: 10), "\(label): seeded daytime brief should load")
        XCTAssertTrue(recovery.waitForExistence(timeout: 10))
        XCTAssertTrue(lastSleep.waitForExistence(timeout: 5))
        XCTAssertTrue(period.waitForExistence(timeout: 5))
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        XCTAssertTrue(legend.waitForExistence(timeout: 5), "\(label): sleep stages should have readable labels")

        assertSameHorizontalEdges(brief, progress, context: "\(label) Today's Brief")
        assertSameHorizontalEdges(recovery, progress, context: "\(label) Recovery & Sleep")
        for (child, parent) in [
            (steps, progress), (sleep, progress),
            (stepsName, steps), (stepsGoal, steps),
            (sleepName, sleep), (sleepGoal, sleep)
        ] {
            assertWithin(child, parent: parent, context: "\(label) \(child.identifier)")
        }
        for child in [lastSleep, period, chart, legend] {
            assertWithin(child, parent: recovery, context: "\(label) \(child.identifier)")
        }

        XCTAssertTrue(scrollFullyIntoViewport(progress, in: scroll),
                      "\(label): daily progress should fit in the viewport")
        addScreenshotAttachment(named: "Today Support \(label) Progress")

        XCTAssertTrue(scrollFullyIntoViewport(brief, in: scroll),
                      "\(label): Today's Brief should fit in the viewport")
        addScreenshotAttachment(named: "Today Support \(label) Brief")

        XCTAssertTrue(scrollTopIntoViewport(recovery, in: scroll),
                      "\(label): Recovery & Sleep header should be visible")
        XCTAssertTrue(visibleViewport(for: scroll).contains(lastSleep.frame),
                      "\(label): last sleep should fit with the card header")
        XCTAssertTrue(visibleViewport(for: scroll).contains(legend.frame),
                      "\(label): sleep stages legend should fit with the card header")
        addScreenshotAttachment(named: "Today Support \(label) Recovery Header")

        XCTAssertTrue(scrollPairFullyIntoViewport(period, chart, in: scroll),
                      "\(label): sleep period and seven-day chart should fit together")
        addScreenshotAttachment(named: "Today Support \(label) Recovery Chart")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func visibleViewport(for scroll: XCUIElement) -> CGRect {
        let window = app.windows.firstMatch.frame
        let navigationBar = app.navigationBars.firstMatch
        let tabBar = app.tabBars.firstMatch
        let top = max(scroll.frame.minY, window.minY,
                      navigationBar.exists ? navigationBar.frame.maxY : window.minY)
        let bottom = min(scroll.frame.maxY, window.maxY,
                         tabBar.exists ? tabBar.frame.minY : window.maxY)
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
            // A 10pt correction left the frame unchanged in the captured run.
            // Keep small corrections large enough to produce a pan.
            let distance = min(max(abs(movement), 24), scroll.frame.height * 0.3)
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(
                CGVector(dx: 0, dy: movement > 0 ? -distance : distance)
            ), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        return visibleViewport(for: scroll).contains(target.frame)
    }

    private func scrollTopIntoViewport(_ target: XCUIElement, in scroll: XCUIElement) -> Bool {
        guard app.scrollToHittableElementIfNeeded(target.identifier, maxSwipes: 12) else { return false }
        for _ in 0..<8 {
            let viewport = visibleViewport(for: scroll)
            let top = target.frame.minY
            if top >= viewport.minY && top + 42 <= viewport.maxY { return true }
            let movement = top + 42 > viewport.maxY
                ? top + 42 - viewport.maxY + 6
                : top - viewport.minY - 6
            let distance = min(max(abs(movement), 24), scroll.frame.height * 0.3)
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(
                CGVector(dx: 0, dy: movement > 0 ? -distance : distance)
            ), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        let viewport = visibleViewport(for: scroll)
        return target.frame.minY >= viewport.minY && target.frame.minY + 42 <= viewport.maxY
    }

    private func scrollPairFullyIntoViewport(
        _ first: XCUIElement, _ second: XCUIElement, in scroll: XCUIElement
    ) -> Bool {
        guard app.scrollToHittableElementIfNeeded(second.identifier, maxSwipes: 12) else { return false }
        for _ in 0..<8 {
            let viewport = visibleViewport(for: scroll)
            let content = first.frame.union(second.frame)
            if viewport.contains(content) { return true }
            guard content.height <= viewport.height else { return false }
            let movement = content.maxY > viewport.maxY
                ? content.maxY - viewport.maxY + 6
                : content.minY - viewport.minY - 6
            let distance = min(max(abs(movement), 24), scroll.frame.height * 0.3)
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(
                CGVector(dx: 0, dy: movement > 0 ? -distance : distance)
            ), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        return visibleViewport(for: scroll).contains(first.frame.union(second.frame))
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
