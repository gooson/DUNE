@preconcurrency import XCTest

/// Seeded L01 reading order, current-day actions, and past-record evidence.
@MainActor
final class LifeFlowUITests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "life" }

    override var additionalLaunchArguments: [String] {
        ["-morningBriefingDisabled", "YES",
         "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
         "--ui-test-theme", "desertWarm", "--ui-test-style", "light",
         "--ui-hero-rhythm-fixtures"]
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func reveal(_ id: String, direction: ScrollDirection = .up) -> XCUIElement {
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(id, maxSwipes: 12, direction: direction),
                      "\(id) should be reachable")
        return element(id)
    }

    private func capture(_ name: String) {
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "AX-" + name
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        if VisualAudit.isEnabled {
            VisualAudit.capture(name)
        } else {
            addScreenshotAttachment(named: name)
        }
    }

    func testCompactHeroAndTodayReadingOrder() {
        navigateToLife()
        let hero = waitForElement(AXID.lifeHeroProgress, timeout: 15)
        let ring = waitForElement("life-hero-ring", timeout: 10)
        let remaining = waitForElement("life-hero-remaining", timeout: 10)
        XCTAssertEqual(waitForElement("life-hero-heading").label, "HABITS")
        XCTAssertEqual(hero.label, "Life progress 1 of 3")
        XCTAssertEqual(ring.frame.width, 104, accuracy: 1)
        XCTAssertEqual(ring.frame.height, ring.frame.width, accuracy: 1)
        XCTAssertTrue(remaining.label.contains("2"), "The hero should show two remaining habits")
        XCTAssertFalse(element("life-hero-narrative").exists)
        XCTAssertFalse(element("life-hero-summary").exists)
        XCTAssertFalse(app.buttons["life-hero-checklist-button"].exists)
        XCTAssertTrue(reveal(AXID.lifeSectionHabits).exists)
        let today = waitForElement("life-habit-group-today")
        XCTAssertTrue(today.descendants(matching: .any)[AXID.lifeHabitRow("Read")].firstMatch.exists)
        XCTAssertTrue(today.descendants(matching: .any)[AXID.lifeHabitRow("Water")].firstMatch.exists)
    }

    func testCategoryFilterDoesNotChangeHeroProgress() {
        navigateToLife()
        let hero = waitForElement(AXID.lifeHeroProgress, timeout: 15)
        let baseline = hero.label
        reveal("life-filter-health").auditTap()
        XCTAssertEqual(hero.label, baseline)
        XCTAssertTrue(element(AXID.lifeHabitRow("Water")).exists)
        XCTAssertTrue(element("life-completed-toggle").exists)
        XCTAssertFalse(element(AXID.lifeHabitRow("Read")).exists)
        reveal("life-filter-growth").auditTap()
        XCTAssertEqual(hero.label, baseline)
        XCTAssertTrue(element(AXID.lifeHabitRow("Read")).exists)
        XCTAssertFalse(element(AXID.lifeHabitRow("Morning Stretch")).exists)
        reveal("life-filter-all").auditTap()
        XCTAssertEqual(hero.label, baseline)
        XCTAssertTrue(element(AXID.lifeHabitRow("Water")).exists)
    }

    func testWaterIncrementAndUndoRestoresTodayValue() {
        navigateToLife()
        let hero = waitForElement(AXID.lifeHeroProgress, timeout: 15)
        let baseline = hero.label
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.lifeHabitRow("Water"), maxSwipes: 8))
        let increase = app.buttons["Increase Water"].firstMatch
        XCTAssertTrue(increase.waitForExistence(timeout: 5))
        increase.auditTap()
        XCTAssertEqual(element("life-habit-value-Water").label, "1")
        XCTAssertTrue(element(AXID.lifeHabitRow("Water")).exists)
        XCTAssertEqual(hero.label, baseline, "One glass does not complete an eight-glass goal")
        let undo = app.buttons["life-undo-button"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "A new record should offer an undo action")
        undo.auditTap()
        XCTAssertEqual(element("life-habit-value-Water").label, "0")
        XCTAssertEqual(hero.label, baseline)
        XCTAssertTrue(increase.waitForExistence(timeout: 5), "The Water row should remain actionable")
        XCTAssertTrue(app.buttons["Decrease Water"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Decrease Water"].firstMatch.isEnabled,
                       "Undo should restore the zero-glass state")
    }

    func testOpeningPastRecordMenuDoesNotMutateToday() {
        navigateToLife()
        let hero = waitForElement(AXID.lifeHeroProgress, timeout: 15)
        let baseline = hero.label
        XCTAssertTrue(app.openLifeHabitActions(named: "Read", maxSwipes: 8))
        XCTAssertEqual(hero.label, baseline)
        let pastAction = app.buttons["life-habit-action-past-record"].firstMatch
        XCTAssertTrue(pastAction.waitForExistence(timeout: 5))
        pastAction.auditTap()
        XCTAssertTrue(app.navigationBars["Past Record"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("habit-past-record-date").exists)
        XCTAssertTrue(element("habit-past-record-habit").exists)
        app.buttons["habit-past-record-cancel"].firstMatch.auditTap()
        XCTAssertEqual(hero.label, baseline, "Opening and canceling the sheet should preserve today")
    }

    func testPastReadTotalReplacesYesterdayAndLeavesTodayUnchanged() {
        navigateToLife()
        let hero = waitForElement(AXID.lifeHeroProgress, timeout: 15)
        let baseline = hero.label
        XCTAssertTrue(app.openLifeHabitActions(named: "Read", maxSwipes: 8))
        app.buttons["life-habit-action-past-record"].firstMatch.auditTap()
        XCTAssertTrue(app.navigationBars["Past Record"].waitForExistence(timeout: 5))
        let total = app.textFields["habit-past-record-total"].firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertTrue(total.value.map { String(describing: $0).contains("30") } ?? false,
                      "The fixture should preload yesterday's 30-minute total")
        XCTAssertTrue(app.fillTextInput("habit-past-record-total", with: "40"))
        let save = app.buttons["habit-past-record-save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.auditTap()
        XCTAssertTrue(app.navigationBars["Past Record"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(hero.label, baseline, "A past record must not change today's completion")
        XCTAssertTrue(app.openLifeHabitActions(named: "Read", maxSwipes: 8))
        app.buttons[AXID.lifeHabitActionHistory].firstMatch.auditTap()
        XCTAssertTrue(waitForElement(AXID.lifeHabitHistoryScreen, timeout: 8).exists)
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "life-habit-history-row-"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let rowText = ([row.label] + row.staticTexts.allElementsBoundByIndex.map(\.label))
            .joined(separator: " ")
        XCTAssertTrue(rowText.contains("40"), "History should show the replaced 40-minute total")
        let late = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "life-habit-history-late-"))
            .firstMatch
        XCTAssertTrue(late.waitForExistence(timeout: 5), "The past entry should identify late recording")
        capture("L05-Life-history-recorded-later")
    }

    func testWeeklyWorkoutBoardSeededContentAndCollapse() {
        navigateToLife()
        let summary = reveal("life-workout-summary")
        XCTAssertTrue(summary.label.contains("DUNE"))
        XCTAssertTrue(summary.label.contains("Apple Health"))
        XCTAssertTrue(summary.label.contains("/"), "The summary should announce completed and total goals")
        XCTAssertTrue(summary.label.contains("–"), "The summary should announce the current week")
        XCTAssertTrue(waitForElement("life-workout-source").label.contains("DUNE"))

        let toggle = app.buttons["life-workout-challenges-toggle"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(toggle.frame.height, 44)

        let sections: [(group: String, metrics: [String])] = [
            ("routine", ["weeklyWorkout5", "weeklyWorkout7"]),
            ("strength", ["weeklyStrength3", "weeklyChest3", "weeklyBack3",
                          "weeklyLowerBody3", "weeklyShoulders3", "weeklyArms3"]),
            ("running", ["weeklyRunning15km"])
        ]
        for section in sections {
            XCTAssertTrue(reveal("life-workout-group-\(section.group)").exists)
            for ruleID in section.metrics {
                let metric = reveal("life-workout-metric-\(ruleID)")
                XCTAssertTrue(metric.label.rangeOfCharacter(from: .decimalDigits) != nil,
                              "\(ruleID) should announce its numeric progress")
                XCTAssertGreaterThan(metric.frame.width, 44, "\(ruleID) should have room for its value")
                if section.group != "routine" {
                    XCTAssertGreaterThan(metric.frame.height, 20, "\(ruleID) should have room for its numeric value")
                }
                if ruleID == "weeklyShoulders3" {
                    XCTAssertTrue(metric.label.contains("0"),
                                  "The seeded Bench Press, Squat and Deadlift have no shoulder workout")
                }
            }
        }

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-workout-challenges-toggle", maxSwipes: 24, direction: .down))
        toggle.auditTap()
        for section in sections {
            XCTAssertFalse(element("life-workout-group-\(section.group)").exists,
                           "Collapsing challenges should remove \(section.group) content")
        }
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-workout-challenges-toggle", maxSwipes: 12))
        toggle.auditTap()
        for section in sections {
            XCTAssertTrue(reveal("life-workout-group-\(section.group)").exists,
                          "Expanding challenges should restore \(section.group) content")
        }
    }

    func testWeeklyWorkoutBoardCustomGoalActions() {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-workout-board-goal-fixture")
        launchApp(with: configuration)
        navigateToLife()
        XCTAssertTrue(reveal("life-workout-goal-Weekly Move").exists)
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-habit-actions-Weekly Move", maxSwipes: 20))
        app.buttons["life-habit-actions-Weekly Move"].firstMatch.auditTap()
        XCTAssertTrue(app.buttons[AXID.lifeHabitActionEdit].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[AXID.lifeHabitActionHistory].firstMatch.exists)
        XCTAssertTrue(app.buttons[AXID.lifeHabitActionArchive].firstMatch.exists)
        XCTAssertFalse(app.buttons["life-habit-action-past-record"].firstMatch.exists,
                       "Auto-linked goals should not offer manual past recording")
        app.buttons[AXID.lifeHabitActionHistory].firstMatch.auditTap()
        XCTAssertTrue(waitForElement(AXID.lifeHabitHistoryScreen, timeout: 8).exists)
        XCTAssertTrue(app.dismissModalIfPresent(cancelIdentifiers: [AXID.lifeHabitHistoryClose]))
        XCTAssertTrue(element("life-workout-goal-Weekly Move").exists)
    }

    func testWeeklyWorkoutBoardKoreanReadingOrder() {
        var configuration = launchConfiguration
        if let language = configuration.additionalArguments.firstIndex(of: "-AppleLanguages") {
            configuration.additionalArguments[language + 1] = "(ko)"
        }
        if let locale = configuration.additionalArguments.firstIndex(of: "-AppleLocale") {
            configuration.additionalArguments[locale + 1] = "ko_KR"
        }
        launchApp(with: configuration)
        navigateToLife()
        let summary = reveal("life-workout-summary")
        XCTAssertTrue(summary.label.contains("DUNE"))
        XCTAssertTrue(summary.label.contains("Apple 건강"))
        XCTAssertTrue(waitForElement("life-workout-source").label.contains("Apple 건강"))
        capture("L01-Life-workout-summary-ko")
        XCTAssertTrue(reveal("life-workout-group-routine").exists)
        capture("L01-Life-workout-routine-ko")
        XCTAssertTrue(reveal("life-workout-group-strength").exists)
        XCTAssertTrue(reveal("life-workout-metric-weeklyArms3").exists)
        capture("L01-Life-workout-strength-end-ko")
        XCTAssertTrue(reveal("life-workout-group-running").exists)
        XCTAssertTrue(reveal("life-workout-source").exists)
        capture("L01-Life-workout-running-end-ko")
    }

    func testCaptureL01WorkoutBoardLight() {
        captureWorkoutBoard(style: "light", maximumAX: false)
    }

    func testCaptureL01WorkoutBoardDark() {
        captureWorkoutBoard(style: "dark", maximumAX: false)
    }

    func testCaptureL01WorkoutBoardMaximumAX() {
        captureWorkoutBoard(style: "dark", maximumAX: true)
    }

    func testHostCaptureWorkoutBoardLight() throws {
        try XCTSkipUnless(isHostCapture, "Host native capture only")
        captureWorkoutBoard(style: "light", maximumAX: false)
    }

    func testHostCaptureWorkoutBoardDark() throws {
        try XCTSkipUnless(isHostCapture, "Host native capture only")
        captureWorkoutBoard(style: "dark", maximumAX: false)
    }

    func testHostCaptureWorkoutBoardMaximumAX() throws {
        try XCTSkipUnless(isHostCapture, "Host native capture only")
        captureWorkoutBoard(style: "dark", maximumAX: true)
    }

    private func captureWorkoutBoard(style: String, maximumAX: Bool) {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-workout-board-goal-fixture")
        if let index = configuration.additionalArguments.firstIndex(of: "--ui-test-style") {
            configuration.additionalArguments[index + 1] = style
        }
        if maximumAX {
            configuration.additionalArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        launchApp(with: configuration)
        navigateToLife()
        let suffix = maximumAX ? "MaxAX" : style
        XCTAssertTrue(reveal("life-workout-summary").exists)
        capture("L01-Life-workout-summary-\(suffix)")
        for group in ["routine", "strength", "running"] {
            XCTAssertTrue(reveal("life-workout-group-\(group)").exists)
            capture("L01-Life-workout-\(group)-\(suffix)")
            if group == "strength" {
                XCTAssertTrue(reveal("life-workout-metric-weeklyArms3").exists)
                capture("L01-Life-workout-strength-end-\(suffix)")
            } else if group == "running" {
                XCTAssertTrue(reveal("life-workout-source").exists)
                capture("L01-Life-workout-running-end-\(suffix)")
            }
        }
    }

    func testCaptureL01AndPastRecordLightDarkAndMaximumAX() throws {
        try XCTSkipIf(isHostCapture, "Use the per-appearance host capture cases")
        captureLifeStates([("light", false), ("dark", false), ("dark", true)])
    }

    func testHostCaptureLight() throws {
        try XCTSkipUnless(isHostCapture, "Host native capture only")
        captureLifeStates([("light", false)])
    }

    func testHostCaptureDark() throws {
        try XCTSkipUnless(isHostCapture, "Host native capture only")
        captureLifeStates([("dark", false)])
    }

    func testHostCaptureMaximumAX() throws {
        try XCTSkipUnless(isHostCapture, "Host native capture only")
        captureLifeStates([("dark", true)])
    }

    private var isHostCapture: Bool {
        ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_HOST_ONLY"] == "1"
    }

    private func captureLifeStates(_ states: [(String, Bool)]) {
        for (style, maximumAX) in states {
            var configuration = launchConfiguration
            if let index = configuration.additionalArguments.firstIndex(of: "--ui-test-style") {
                configuration.additionalArguments[index + 1] = style
            }
            if maximumAX {
                configuration.additionalArguments += [
                    "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
                ]
            }
            launchApp(with: configuration)
            navigateToLife()
            let suffix = maximumAX ? "MaxAX" : style
            let hero = waitForElement(AXID.lifeHeroProgress, timeout: 15)
            XCTAssertTrue(hero.exists)
            if maximumAX {
                XCTAssertFalse(element("life-hero-ring").exists)
                XCTAssertTrue(waitForElement("life-hero-external-progress").exists)
            } else {
                XCTAssertTrue(waitForElement("life-hero-ring").exists)
            }
            capture("L01-Life-Habits-hero-\(suffix)")
            XCTAssertTrue(reveal("life-habit-group-today").exists)
            capture("L01-Life-Habits-today-\(suffix)")
            XCTAssertTrue(reveal("life-hero-trend").exists)
            capture("L01-Life-Habits-rhythm-\(suffix)")
            XCTAssertTrue(reveal("life-past-record-button", direction: .down).exists)
            app.buttons["life-past-record-button"].firstMatch.auditTap()
            XCTAssertTrue(app.navigationBars["Past Record"].waitForExistence(timeout: 5))
            capture("L09-Past-Record-form-\(suffix)")
            if style == "light" && !maximumAX {
                app.buttons["habit-past-record-cancel"].firstMatch.auditTap()
                reveal("habit-heatmap").auditTap()
                XCTAssertTrue(app.navigationBars["Activity Detail"].waitForExistence(timeout: 8))
                capture("L07-Habit-history-summary-light")
                reveal("habit-completion-chart-title")
                capture("L07-Habit-history-rates-light")
                launchApp(with: configuration)
                navigateToLife()
                reveal("life-weekly-report-button").auditTap()
                XCTAssertTrue(app.navigationBars["Weekly Report"].waitForExistence(timeout: 8))
                capture("L08-Weekly-report-light")
            }
        }
    }
}
