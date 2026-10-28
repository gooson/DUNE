@preconcurrency import XCTest

@MainActor
final class LifeRegressionTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "life" }

    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US"
        ]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    func testDesertHeroKeepsTodayReachableWithoutChecklistCTA() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["--ui-test-theme", "desertWarm"]
        launchApp(with: configuration)
        ensureLifeRoot()

        XCTAssertTrue(waitForElement(AXID.lifeHeroProgress, timeout: 8).exists)
        XCTAssertFalse(app.buttons["life-hero-checklist-button"].exists,
                       "The compact hero should leave checklist navigation to the Today section")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.lifeSectionHabits, maxSwipes: 6),
                      "Today should remain reachable by scrolling below the compact hero")
        XCTAssertTrue(waitForElement("life-habit-group-today").exists)
    }

    func testLifeRootRendersAndAddFlowCreatesNewHabit() throws {
        ensureLifeRoot()
        XCTAssertTrue(waitForElement(AXID.lifeHeroProgress, timeout: 15).exists, "Life hero should exist in seeded state")
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.lifeSectionHabits, maxSwipes: 4), "Habits section should be reachable")
        XCTAssertTrue(elementExists(AXID.lifeSectionHabits, timeout: 5), "Habits section should render in seeded state")

        XCTAssertTrue(app.openLifeNewHabitForm(), "New Habit menu action should open the habit form")

        let nameField = app.textFields[AXID.habitFormName].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Habit form should appear from the Life toolbar")
        XCTAssertTrue(app.fillTextInput(AXID.habitFormName, with: "Evening Walk"), "Habit name field should accept a new habit")

        let saveButton = app.descendants(matching: .any)[AXID.habitFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Habit save button should exist")
        saveButton.auditTap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: nameField)
        waitForExpectations(timeout: 5)

        XCTAssertTrue(
            app.openLifeHabitActions(named: "Evening Walk", maxSwipes: 8),
            "Newly saved habit should expose its action menu on the Life list"
        )
    }

    func testWeeklyAndFutureRecurringHabitsStayOutsideTodayProgress() throws {
        ensureLifeRoot()
        let hero = app.descendants(matching: .any)[AXID.lifeHeroProgress].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10), "Seeded Life hero should render")
        let baselineProgress = hero.label
        XCTAssertEqual(baselineProgress, "Life progress 1 of 3", "The seed should start with one of three daily habits completed")

        createScheduledHabit(named: "Weekly Swim", frequencyID: AXID.habitFormFrequencyWeekly)
        XCTAssertEqual(hero.label, baselineProgress, "A weekly goal must not increase today's denominator")

        createScheduledHabit(named: "Seven Day Reset", frequencyID: "habit-form-frequency-interval", startsOnFirstCompletion: true)
        XCTAssertEqual(hero.label, baselineProgress, "A future recurring habit must not increase today's denominator")

        let today = app.descendants(matching: .any)["life-habit-group-today"].firstMatch
        let weekly = app.descendants(matching: .any)["life-habit-group-weekly"].firstMatch
        let upcoming = app.descendants(matching: .any)["life-habit-group-upcoming"].firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 5), "Seeded daily habits should remain in Today")
        XCTAssertTrue(weekly.waitForExistence(timeout: 5), "Weekly group should appear after adding a weekly habit")
        XCTAssertTrue(upcoming.waitForExistence(timeout: 5), "Upcoming group should appear for a recurring habit awaiting its first completion")
        let completedToggle = app.buttons["life-completed-toggle"].firstMatch
        XCTAssertTrue(completedToggle.waitForExistence(timeout: 5), "Completed habits should have a disclosure")
        completedToggle.auditTap()
        XCTAssertTrue(today.descendants(matching: .any)[AXID.lifeHabitRow("Morning Stretch")].firstMatch.exists)
        XCTAssertTrue(weekly.descendants(matching: .any)[AXID.lifeHabitRow("Weekly Swim")].firstMatch.exists)
        let upcomingToggle = app.buttons["life-habit-group-upcoming"].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-habit-group-upcoming", maxSwipes: 8))
        upcomingToggle.auditTap()
        XCTAssertTrue(upcoming.descendants(matching: .any)[AXID.lifeHabitRow("Seven Day Reset")].firstMatch.exists)
        XCTAssertFalse(today.descendants(matching: .any)[AXID.lifeHabitRow("Weekly Swim")].firstMatch.exists)
        XCTAssertFalse(today.descendants(matching: .any)[AXID.lifeHabitRow("Seven Day Reset")].firstMatch.exists)

        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.lifeHeroProgress, maxSwipes: 8, direction: .down))
        attachLifeScreenshot("L01 Today hero with scheduled habits")
        for (groupID, name) in [
            ("life-habit-group-today", "L01 Today checklist"),
            ("life-habit-group-weekly", "L01 Weekly habits"),
            ("life-habit-group-upcoming", "L01 Upcoming habits")
        ] {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(groupID, maxSwipes: 10), "\(name) should be reachable")
            if groupID == "life-habit-group-upcoming" {
                // A hittable group can still extend below an iPad's viewport.
                // Capture the complete pending schedule and its explanatory copy.
                let group = app.descendants(matching: .any)[groupID].firstMatch
                let scroll = app.scrollViews.firstMatch
                let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
                for _ in 0..<6 where !viewport.contains(group.frame) {
                    if group.frame.maxY > viewport.maxY {
                        scroll.swipeUp(velocity: .slow)
                    } else {
                        scroll.swipeDown(velocity: .slow)
                    }
                }
                XCTAssertTrue(viewport.contains(group.frame), "Upcoming schedule copy should fit completely in the capture viewport")
            }
            attachLifeScreenshot(name)
        }
    }

    func testEditFlowRenamesSeededHabit() throws {
        openActionsMenu(for: "Morning Stretch")

        let editButton = app.descendants(matching: .any)[AXID.lifeHabitActionEdit].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit action should appear from the habit actions menu")
        editButton.auditTap()

        let nameField = app.textFields[AXID.habitFormName].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Edit habit form should appear")
        XCTAssertTrue(app.fillTextInput(AXID.habitFormName, with: "Morning Stretch AM"), "Edit form should allow renaming a habit")

        XCTAssertTrue(
            app.waitAndTap(AXID.habitFormSave, timeout: 5) || app.buttons["Save"].firstMatch.waitForExistence(timeout: 2),
            "Habit save button should exist in edit mode"
        )
        if app.buttons["Save"].firstMatch.exists {
            app.buttons["Save"].firstMatch.auditTap()
        }

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: nameField)
        waitForExpectations(timeout: 5)

        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.lifeHabitActions("Morning Stretch AM"), maxSwipes: 6),
            "Edited habit should refresh its actions identifier after saving"
        )
    }

    func testHabitHistoryShowsSeededEntriesAndDismisses() throws {
        openHistory(for: "Morning Stretch")

        let historyScreen = app.descendants(matching: .any)[AXID.lifeHabitHistoryScreen].firstMatch
        XCTAssertTrue(historyScreen.waitForExistence(timeout: 8), "History should open from the seeded habit actions menu")

        let habitSummary = app.descendants(matching: .any)[AXID.lifeHabitRow("Morning Stretch")].firstMatch
        if app.windows.firstMatch.horizontalSizeClass == .regular {
            XCTAssertTrue(habitSummary.exists, "Habit summary should remain alongside its history inspector")
        }

        let firstRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "life-habit-history-row-"))
            .firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "Seeded habit history should expose at least one action row")
        let rowText = ([firstRow.label] + firstRow.staticTexts.allElementsBoundByIndex.map(\.label))
            .joined(separator: " ")
        XCTAssertTrue(rowText.contains("Completed"), "Seeded Morning Stretch history should show its completion")

        XCTAssertTrue(
            app.dismissModalIfPresent(cancelIdentifiers: [AXID.lifeHabitHistoryClose]),
            "History should dismiss through its close action"
        )
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: historyScreen)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(habitSummary.waitForExistence(timeout: 5), "Closing history should preserve the original habit summary")
    }

    func testHabitHistoryShowsEmptyStateForHabitWithoutLogs() throws {
        openHistory(for: "Read")

        let historyScreen = app.descendants(matching: .any)[AXID.lifeHabitHistoryScreen].firstMatch
        XCTAssertTrue(historyScreen.waitForExistence(timeout: 8), "History sheet should open for a habit without logs")

        let emptyState = app.descendants(matching: .any)[AXID.lifeHabitHistoryEmpty].firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "History sheet should show an empty state when no cycle actions exist")

        XCTAssertTrue(
            app.dismissModalIfPresent(cancelIdentifiers: [AXID.lifeHabitHistoryClose]),
            "Empty history sheet should dismiss through the shared modal helper"
        )
    }

    func testVisualAuditWeeklyReport() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-weekly-report-button", maxSwipes: 8),
                      "UNVERIFIED: weekly report entry is unavailable")
        app.buttons["life-weekly-report-button"].firstMatch.auditTap()
        XCTAssertTrue(app.navigationBars["Weekly Report"].waitForExistence(timeout: 5), "Weekly report should open")
        let reportScroll = app.scrollViews["life-weekly-report-scroll"].firstMatch
        XCTAssertTrue(reportScroll.waitForExistence(timeout: 5), "The report must own its scroll container")
        VisualAudit.capture("Life weekly report upper viewport")
        for identifier in ["life-weekly-report-best", "life-weekly-report-improvement"] {
            let landmark = app.descendants(matching: .any)[identifier].firstMatch
            for _ in 0..<10 where !(landmark.exists && landmark.isHittable) {
                reportScroll.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(landmark.exists && landmark.isHittable, "Report section must be reachable: \(identifier)")
            VisualAudit.capture("Life weekly report section \(identifier)")
        }
    }

    func testVisualAuditHabitHeatmap() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        let heatmap = app.buttons["habit-heatmap"].firstMatch
        let rootScroll = app.scrollViews.firstMatch
        for _ in 0..<16 where !(heatmap.exists && heatmap.isHittable) {
            let towardTop = heatmap.exists && heatmap.frame.midY < rootScroll.frame.midY
            let startY = towardTop ? 0.25 : 0.75
            let endY = towardTop ? 0.75 : 0.25
            rootScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: startY))
                .press(forDuration: 0.05, thenDragTo: rootScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: endY)))
        }
        XCTAssertTrue(heatmap.exists && heatmap.isHittable,
                      "UNVERIFIED: habit heatmap entry is unavailable")
        VisualAudit.capture("Life root heatmap before opening detail")
        app.descendants(matching: .any)["habit-heatmap"].firstMatch.auditTap()
        XCTAssertTrue(app.navigationBars["Activity Detail"].waitForExistence(timeout: 5), "Heatmap detail should open")
        captureLifeAuditScroll("Life heatmap detail")
    }

    func testVisualAuditHabitManagement() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        openActionsMenu(for: "Morning Stretch")
        XCTAssertTrue(app.waitAndTap(AXID.lifeHabitActionArchive), "Seeded habit should be archivable")
        let identifiedEntry = app.descendants(matching: .any)["life-archived-habits-link"].firstMatch
        let labeledEntry = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "1 archived habits"))
        var managementEntry: XCUIElement?
        for attempt in 0...8 {
            if identifiedEntry.exists && identifiedEntry.isHittable {
                managementEntry = identifiedEntry
            } else {
                managementEntry = labeledEntry.allElementsBoundByIndex.first(where: { $0.isHittable })
            }
            if managementEntry != nil { break }
            guard attempt < 8,
                  let scroll = app.scrollViews.allElementsBoundByIndex.first(where: { $0.isHittable }) else { break }
            // Drag through the outer margin so nested habit controls cannot consume the gesture.
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.25)))
        }
        guard let managementEntry else {
            XCTFail("UNVERIFIED: habit management entry is unavailable: \(app.debugDescription)")
            return
        }
        managementEntry.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)["habit-management-screen"].firstMatch.waitForExistence(timeout: 5),
                      "Habit management should open")
        captureLifeAuditScroll("Habit management active")
        let archived = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Archived")).firstMatch
        XCTAssertTrue(archived.waitForExistence(timeout: 5), "Archived filter should be available")
        archived.auditTap()
        captureLifeAuditScroll("Habit management archived")
        let restoreID = "habit-management-restore-Morning Stretch"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(restoreID, maxSwipes: 8),
                      "Archived habit Restore action must be reachable")
        VisualAudit.capture("Archived habit with reachable Restore")
        let historyID = "habit-management-history-Morning Stretch"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(historyID, maxSwipes: 8),
                      "Archived habit History action must be reachable")
        app.buttons[historyID].firstMatch.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)["habit-management-history-screen"].firstMatch
            .waitForExistence(timeout: 8), "Management history sheet should open")
        VisualAudit.capture("Archived habit management history")
    }

    private func captureLifeAuditScroll(_ route: String) {
        VisualAudit.capture("\(route) initial viewport")
        guard let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) else {
            XCTFail("UNVERIFIED: \(route) has no visible scroll container")
            return
        }
        for index in 1...5 {
            scroll.swipeUp()
            VisualAudit.capture("\(route) lower viewport \(index) of 5")
        }
        for _ in 0..<5 { scroll.swipeDown() }
        VisualAudit.capture("\(route) returned upper viewport")
    }

    private func createScheduledHabit(
        named name: String,
        frequencyID: String,
        startsOnFirstCompletion: Bool = false
    ) {
        XCTAssertTrue(app.openLifeNewHabitForm(), "New Habit form should open for \(name)")
        let nameField = app.textFields[AXID.habitFormName].firstMatch
        XCTAssertTrue(app.fillTextInput(AXID.habitFormName, with: name))
        _ = app.dismissKeyboardIfPresent()
        XCTAssertTrue(app.scrollToElementInPrimaryFormIfNeeded(frequencyID, maxSwipes: 6), "Frequency option should be reachable")
        app.descendants(matching: .any)[frequencyID].firstMatch.auditTap()

        if startsOnFirstCompletion {
            XCTAssertTrue(app.scrollToElementInPrimaryFormIfNeeded("habit-interval-stepper", maxSwipes: 6))
            let intervalStepper = app.descendants(matching: .any)["habit-interval-stepper"].firstMatch
            XCTAssertTrue(intervalStepper.waitForExistence(timeout: 5), "Recurring form should expose its day interval")
            XCTAssertTrue(intervalStepper.label.contains("7"), "Recurring habit should use the default seven-day interval")
            XCTAssertTrue(app.scrollToElementInPrimaryFormIfNeeded("habit-interval-start-point", maxSwipes: 6))
            app.descendants(matching: .any)["habit-interval-start-point"].firstMatch.auditTap()
            let firstCompletion = app.buttons["First Completion"].firstMatch
            XCTAssertTrue(firstCompletion.waitForExistence(timeout: 5), "First Completion should be available as a start point")
            firstCompletion.auditTap()
            XCTAssertTrue(app.staticTexts["Schedule starts after the first completion"].firstMatch.waitForExistence(timeout: 5),
                          "Recurring habit should wait for its first completion")
        }

        // The sheet's navigation buttons leave the AX tree while its Form is scrolled.
        // Restore the form's top before looking for Save.
        let saveButton = app.buttons[AXID.habitFormSave].firstMatch
        let form = app.collectionViews.firstMatch
        XCTAssertTrue(form.exists, "\(name) form should expose its scroll container")
        for _ in 0..<6 where !saveButton.exists {
            form.swipeDown()
        }
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "\(name) Save action should return at the top of the form")
        saveButton.auditTap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: nameField)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.descendants(matching: .any)[AXID.lifeHabitRow(name)].firstMatch.waitForExistence(timeout: 8),
                      "\(name) should appear on the Life list")
    }

    private func attachLifeScreenshot(_ name: String) {
        VisualAudit.capture(name)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func ensureLifeRoot() {
        let hero = app.descendants(matching: .any)[AXID.lifeHeroProgress].firstMatch
        if hero.exists || hero.waitForExistence(timeout: 8) {
            return
        }

        navigateToLife()
        XCTAssertTrue(hero.waitForExistence(timeout: 10), "Life hero should exist after returning to the root tab")
    }

    private func openActionsMenu(for habitName: String) {
        ensureLifeRoot()
        if habitName == "Morning Stretch" {
            let completedToggle = app.buttons["life-completed-toggle"].firstMatch
            XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-completed-toggle", maxSwipes: 8))
            completedToggle.auditTap()
        }
        XCTAssertTrue(
            app.openLifeHabitActions(named: habitName, maxSwipes: 8),
            "\(habitName) actions menu should be reachable"
        )
    }

    private func openHistory(for habitName: String) {
        openActionsMenu(for: habitName)

        let historyButton = app.descendants(matching: .any)[AXID.lifeHabitActionHistory].firstMatch
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5), "History action should appear from the habit actions menu")
        historyButton.auditTap()
    }
}
