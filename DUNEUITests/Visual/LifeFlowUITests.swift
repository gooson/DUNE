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

    @discardableResult
    private func revealPastRecordControl(_ identifier: String) -> XCUIElement {
        let form = app.collectionViews.firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        let control = app.descendants(matching: .any)[identifier].firstMatch
        // The native medium Form instantiates lower rows only after scrolling.
        for _ in 0..<8 where !control.exists { form.swipeUp(velocity: .slow) }
        XCTAssertTrue(app.revealFullyVisible(identifier, in: form, maxMoves: 12))
        return control
    }

    private func tapPastRecordAction(_ identifier: String) {
        let form = app.collectionViews.firstMatch
        let action = app.buttons[identifier].firstMatch
        // Restore the sheet toolbar after scrolling within the actual Form.
        for _ in 0..<10 where !(action.exists && action.isHittable) {
            form.swipeDown(velocity: .slow)
        }
        XCTAssertTrue(action.waitForExistence(timeout: 5) && action.isHittable)
        action.auditTap()
    }

    private func tapPastReadSave() -> Bool {
        let total = app.textFields["habit-past-record-total"].firstMatch
        let picker = app.buttons["habit-past-record-habit"].firstMatch
        let forms = app.collectionViews
        let matchingForms = forms.allElementsBoundByIndex.enumerated().filter {
            $0.element.textFields["habit-past-record-total"].firstMatch.exists
        }
        guard matchingForms.count == 1 else { return false }
        // Keep the verified Form's index when its lower row leaves the lazy AX tree.
        let form = forms.element(boundBy: matchingForms[0].offset)
        let originalFormCount = forms.count
        let navigationBar = app.navigationBars["Past Record"].firstMatch
        let save = navigationBar.buttons["habit-past-record-save"].firstMatch
        let window = app.windows.firstMatch

        func usable(_ frame: CGRect) -> Bool {
            !frame.isEmpty && !frame.isNull &&
                frame.minX.isFinite && frame.maxX.isFinite &&
                frame.minY.isFinite && frame.maxY.isFinite
        }

        guard total.exists, total.value as? String == "40",
              picker.exists, picker.label == "Habit, Read" else { return false }

        // Preserve the existing ten-gesture maximum, with a final eligibility check.
        for move in 0...10 {
            guard window.exists, navigationBar.exists else { return false }
            let windowFrame = window.frame
            let navigationFrame = navigationBar.frame
            guard usable(windowFrame), usable(navigationFrame) else { return false }
            if save.exists {
                let frame = save.frame
                // Geometry must precede isHittable: a collapsed placeholder can exist.
                if usable(frame), windowFrame.contains(frame), navigationFrame.contains(frame),
                   save.isHittable, save.isEnabled {
                    guard picker.exists, picker.label == "Habit, Read" else { return false }
                    if total.exists, total.value as? String != "40" { return false }
                    VisualAudit.capture("L09 native Save toolbar restored")
                    save.auditTap()
                    return true
                }
            }
            guard move < 10, forms.count == originalFormCount, form.exists else { return false }
            let formFrame = form.frame
            guard usable(formFrame) else { return false }
            let intersection = formFrame.intersection(windowFrame)
            guard usable(intersection) else { return false }
            let top = max(intersection.minY, navigationFrame.maxY)
            var bottom = intersection.maxY
            let keyboard = app.keyboards.firstMatch
            if keyboard.exists {
                let keyboardFrame = keyboard.frame
                guard usable(keyboardFrame) else { return false }
                if keyboardFrame.intersects(intersection) {
                    bottom = min(bottom, keyboardFrame.minY)
                }
            }
            let viewport = CGRect(x: intersection.minX, y: top,
                                  width: intersection.width, height: max(0, bottom - top))
                .insetBy(dx: 12, dy: 12)
            guard usable(viewport), viewport.height >= 44 else { return false }
            let x = (viewport.midX - formFrame.minX) / formFrame.width
            let start = form.coordinate(withNormalizedOffset: CGVector(
                dx: x, dy: (viewport.minY + viewport.height * 0.25 - formFrame.minY) / formFrame.height
            ))
            let end = form.coordinate(withNormalizedOffset: CGVector(
                dx: x, dy: (viewport.minY + viewport.height * 0.75 - formFrame.minY) / formFrame.height
            ))
            start.press(forDuration: 0.05, thenDragTo: end)
            VisualAudit.capture("L09 numeric Form visible-area drag \(move + 1)")
            if picker.exists, picker.label != "Habit, Read" { return false }
            if total.exists, total.value as? String != "40" { return false }
        }
        return false
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
        let readDate = app.staticTexts["habit-past-record-hero-date"].firstMatch
        XCTAssertTrue(readDate.waitForExistence(timeout: 5) && !readDate.label.isEmpty)
        capture("L09 duration record hero and date")
        tapPastRecordAction("habit-past-record-cancel")
        XCTAssertEqual(hero.label, baseline, "Opening and canceling the sheet should preserve today")

        XCTAssertTrue(app.openLifeHabitActions(named: "Water", maxSwipes: 8))
        app.buttons["life-habit-action-past-record"].firstMatch.auditTap()
        XCTAssertTrue(app.navigationBars["Past Record"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["habit-past-record-hero-date"].firstMatch.exists)
        revealPastRecordControl("habit-past-record-total")
        XCTAssertTrue(app.textFields["habit-past-record-total"].firstMatch.exists,
                      "Count habits use a numeric total")
        capture("L09 count record")
        tapPastRecordAction("habit-past-record-cancel")

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-completed-toggle", maxSwipes: 8))
        app.buttons["life-completed-toggle"].firstMatch.auditTap()
        XCTAssertTrue(app.openLifeHabitActions(named: "Morning Stretch", maxSwipes: 8))
        app.buttons["life-habit-action-past-record"].firstMatch.auditTap()
        XCTAssertTrue(app.navigationBars["Past Record"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["habit-past-record-hero-date"].firstMatch.exists)
        revealPastRecordControl("habit-past-record-completed")
        XCTAssertTrue(app.switches["habit-past-record-completed"].firstMatch.exists,
                      "Check habits use a completion toggle")
        capture("L09 check record")
        tapPastRecordAction("habit-past-record-cancel")
        XCTAssertEqual(hero.label, baseline, "Canceling every record kind must preserve today")
    }

    func testPastReadTotalReplacesYesterdayAndLeavesTodayUnchanged() {
        navigateToLife()
        let hero = waitForElement(AXID.lifeHeroProgress, timeout: 15)
        let baseline = hero.label
        XCTAssertTrue(app.openLifeHabitActions(named: "Read", maxSwipes: 8))
        app.buttons["life-habit-action-past-record"].firstMatch.auditTap()
        XCTAssertTrue(app.navigationBars["Past Record"].waitForExistence(timeout: 5))
        revealPastRecordControl("habit-past-record-total")
        let total = app.textFields["habit-past-record-total"].firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertTrue(total.value.map { String(describing: $0).contains("30") } ?? false,
                      "The fixture should preload yesterday's 30-minute total")
        total.auditTap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        capture("L09 focused duration total and software keyboard")
        let existingTotal = total.value as? String ?? ""
        XCTAssertEqual(existingTotal, "30")
        total.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingTotal.count))
        let clearedTotal = total.value as? String ?? ""
        XCTAssertTrue(clearedTotal.isEmpty || clearedTotal == total.placeholderValue,
                      "Clear the original total before typing its replacement")
        total.typeText("40")
        XCTAssertEqual(total.value as? String, "40")
        capture("L09 replacement total before native Save")
        XCTAssertTrue(tapPastReadSave(), "Save must preserve Read and its replacement total")
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

    func testPastRecordKindsAtMaximumAccessibilitySize() {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToLife()
        let today = waitForElement(AXID.lifeHeroProgress, timeout: 15)
        let baseline = today.label

        for (habit, controlID) in [("Read", "habit-past-record-total"),
                                   ("Water", "habit-past-record-total"),
                                   ("Morning Stretch", "habit-past-record-completed")] {
            if habit == "Morning Stretch" {
                XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-completed-toggle", maxSwipes: 8))
                app.buttons["life-completed-toggle"].firstMatch.auditTap()
            }
            XCTAssertTrue(app.openLifeHabitActions(named: habit, maxSwipes: 10))
            let action = app.buttons["life-habit-action-past-record"].firstMatch
            XCTAssertTrue(action.waitForExistence(timeout: 5))
            action.auditTap()
            let sheet = app.navigationBars["Past Record"]
            XCTAssertTrue(sheet.waitForExistence(timeout: 5))
            let form = app.collectionViews.firstMatch
            XCTAssertTrue(form.waitForExistence(timeout: 5))
            XCTAssertTrue(app.revealTextBody("habit-past-record-hero-date", in: form))
            let displayedDate = app.staticTexts["habit-past-record-hero-date"].firstMatch.label
            XCTAssertFalse(displayedDate.isEmpty, "The actual selected past date should remain readable")
            capture("L09 MAX \(habit) selected date")
            revealPastRecordControl("habit-past-record-date")
            revealPastRecordControl(controlID)
            XCTAssertTrue(app.descendants(matching: .any)[controlID].firstMatch.isHittable)
            capture("L09 MAX \(habit) record control")

            let dateHero = app.staticTexts["habit-past-record-hero-date"].firstMatch
            for _ in 0..<10 where !dateHero.exists { form.swipeDown(velocity: .slow) }
            XCTAssertTrue(app.revealTextBody("habit-past-record-hero-date", in: form))
            tapPastRecordAction("habit-past-record-cancel")
            XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
            XCTAssertEqual(today.label, baseline, "Cancel must preserve today's progress")
        }
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
        alignWorkoutCapture("life-workout-summary", maximumAX: maximumAX)
        capture("L01-Life-workout-summary-\(suffix)")
        for group in ["routine", "strength", "running"] {
            alignWorkoutCapture("life-workout-group-\(group)", maximumAX: maximumAX)
            capture("L01-Life-workout-\(group)-\(suffix)")
            if group == "strength" {
                alignWorkoutCapture("life-workout-metric-weeklyArms3", maximumAX: maximumAX)
                capture("L01-Life-workout-strength-end-\(suffix)")
            } else if group == "running" {
                alignWorkoutCapture("life-workout-source", maximumAX: maximumAX, alignBottom: true)
                capture("L01-Life-workout-running-end-\(suffix)")
            }
        }
    }

    private func alignWorkoutCapture(_ id: String, maximumAX: Bool, alignBottom: Bool = false) {
        let target = reveal(id)
        guard maximumAX || isHostCapture else { return }
        let window = app.windows.firstMatch.frame
        let top = max(window.minY, app.navigationBars.firstMatch.frame.maxY) + 20
        let tabBar = app.tabBars.firstMatch
        let hasBottomTabBar = tabBar.exists && tabBar.frame.minY > window.midY && tabBar.frame.width > window.width / 2
        let bottom = (hasBottomTabBar ? tabBar.frame.minY : window.maxY) - 20
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<8 {
            let offset = alignBottom ? max(0, target.frame.maxY - bottom) : target.frame.minY - top
            if abs(offset) < 16 { break }
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            start.press(forDuration: 0.05,
                        thenDragTo: start.withOffset(CGVector(dx: 0, dy: -max(-240, min(240, offset)))),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        if target.frame.height <= bottom - top {
            XCTAssertGreaterThanOrEqual(target.frame.minY, top - 16, "\(id) should clear the navigation bar")
            XCTAssertLessThanOrEqual(target.frame.maxY, bottom + 16, "\(id) should clear the floating tab bar")
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
