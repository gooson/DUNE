@preconcurrency import XCTest

/// Smoke tests for the Life tab.
/// Verifies key UI elements exist and the screen renders without crashing.
@MainActor
final class LifeSmokeTests: UITestBaseCase {
    override var initialTabSelectionArgument: String? { "life" }

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    // MARK: - Elements

    func testLifeTabLoads() throws {
        let navBar = app.navigationBars["Life"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 8), "Life navigation title should appear")
    }

    func testToolbarAddButtonExists() throws {
        XCTAssertTrue(
            elementExists(AXID.lifeToolbarAdd, timeout: 5),
            "Life add button should exist in toolbar"
        )
    }

    // MARK: - Habit Form

    func testEmptyStarterRemainsActionableAtMaximumAccessibilityTextSize() throws {
        let textSizeArguments = [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: textSizeArguments)
        launchApp(with: configuration)
        XCTAssertEqual(Array(app.launchArguments.suffix(2)), textSizeArguments,
                       "This launch must explicitly request the largest accessibility text category")
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8), "Life should load at maximum accessibility text size")

        XCTAssertTrue(app.openLifeNewHabitForm(),
                      "Toolbar New Habit should remain reachable at maximum accessibility text size")
        XCTAssertTrue(app.textFields[AXID.habitFormName].firstMatch.waitForExistence(timeout: 5),
                      "The starter should open the habit form at maximum accessibility text size")
        XCTAssertTrue(app.dismissModalIfPresent(cancelIdentifiers: [AXID.habitFormCancel]),
                      "Cancel should dismiss the form without creating a habit")

        XCTAssertTrue(app.buttons[AXID.lifeToolbarAdd].waitForExistence(timeout: 5),
                      "Cancel should preserve the toolbar add action")
    }

    func testEmptyStarterAddCancelPreservesEmptyState() throws {
        XCTAssertTrue(elementExists(AXID.lifeHeroProgress, timeout: 8), "Empty starter should appear")
        XCTAssertTrue(app.openLifeNewHabitForm(), "Toolbar should offer New Habit")

        let nameField = app.textFields[AXID.habitFormName].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Add Habit should open the habit form")
        XCTAssertTrue(
            app.dismissModalIfPresent(cancelIdentifiers: [AXID.habitFormCancel]),
            "Cancel should dismiss the habit form without creating a habit"
        )

        let addButton = app.buttons[AXID.lifeToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Cancel should preserve toolbar add")
        XCTAssertTrue(addButton.isHittable, "Toolbar add should remain actionable after cancel")
        XCTAssertFalse(app.buttons["life-empty-add"].exists, "Empty state should avoid a duplicate add action")
    }

    func testEmptyStarterOpensTemplates() throws {
        XCTAssertTrue(app.waitAndTap(AXID.lifeToolbarAdd), "Toolbar add menu should open")
        XCTAssertTrue(app.waitAndTap(AXID.lifeToolbarTemplate), "Toolbar should offer From Template")
        XCTAssertTrue(elementExists("habit-template-list", timeout: 3), "Template picker should appear")
        XCTAssertTrue(
            app.dismissModalIfPresent(cancelIdentifiers: ["habit-template-cancel"]),
            "Template picker should dismiss without creating a habit"
        )

        XCTAssertTrue(
            app.buttons[AXID.lifeToolbarAdd].waitForExistence(timeout: 3),
            "Cancel should return to the Life toolbar"
        )
        XCTAssertTrue(app.buttons[AXID.lifeToolbarAdd].isHittable, "Add Habit should remain actionable")
    }

    func testHabitFormOpens() throws {
        XCTAssertTrue(app.openLifeNewHabitForm(), "New Habit menu action should open the habit form")

        // Habit form sheet should appear
        let nameField = app.textFields[AXID.habitFormName]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Habit name field should appear")

        XCTAssertTrue(
            app.scrollToElementInPrimaryFormIfNeeded(AXID.habitFormType, maxSwipes: 4),
            "Habit type picker should appear"
        )
        XCTAssertTrue(
            app.scrollToElementInPrimaryFormIfNeeded(AXID.habitFormReminderTime, maxSwipes: 6),
            "Reminder time picker should appear in the new habit form"
        )
    }

    func testHabitFormCancelDismisses() throws {
        let addButton = app.buttons[AXID.lifeToolbarAdd].firstMatch
        XCTAssertTrue(app.openLifeNewHabitForm(), "New Habit menu action should open the habit form")

        let cancelButton = app.descendants(matching: .any)[AXID.habitFormCancel].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Habit form cancel button should exist")
        XCTAssertTrue(app.dismissModalIfPresent(cancelIdentifiers: [AXID.habitFormCancel]), "Habit form should dismiss via shared helper")

        // Sheet should be dismissed — add button should be visible again
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Habit form should be dismissed")
    }

    func testSaveEmptyHabitKeepsFormPresented() throws {
        XCTAssertTrue(app.openLifeNewHabitForm(), "New Habit menu action should open the habit form")

        let nameField = app.textFields[AXID.habitFormName].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Habit name field should appear")
        XCTAssertTrue(app.waitAndTap(AXID.habitFormSave), "Habit form save button should exist")

        // Empty name should fail validation and keep sheet visible
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Habit form should remain visible on validation failure")
    }

    func testWeeklyFrequencyShowsStepper() throws {
        XCTAssertTrue(app.openLifeNewHabitForm(), "New Habit menu action should open the habit form")

        XCTAssertTrue(
            app.scrollToElementInPrimaryFormIfNeeded(AXID.habitFormFrequencyWeekly, maxSwipes: 5),
            "Frequency picker should exist"
        )
        let weeklySegment = app.descendants(matching: .any)[AXID.habitFormFrequencyWeekly].firstMatch
        XCTAssertTrue(weeklySegment.waitForExistence(timeout: 3), "Weekly segment should exist")
        weeklySegment.tap()

        let weeklyStepper = app.descendants(matching: .any)["habit-weekly-stepper"].firstMatch
        XCTAssertTrue(weeklyStepper.waitForExistence(timeout: 3), "Weekly stepper should appear when frequency is weekly")
    }
}

// MARK: - Seeded Life Tests

/// Tests that require mock habit data to verify hero section and habit rows.
@MainActor
final class LifeSeededSmokeTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "life" }

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    func testHeroProgressExists() throws {
        XCTAssertTrue(
            elementExists(AXID.lifeHeroProgress, timeout: 15),
            "Life hero progress card should exist when habits are seeded"
        )
        XCTAssertFalse(app.buttons["life-empty-add"].exists, "Seeded habits should not show the empty starter")
        XCTAssertFalse(app.buttons["life-empty-template"].exists, "Seeded habits should not show the empty template entry")
    }

    func testWeeklyReflectionOpensMeasuredComparison() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        launchApp(with: configuration)
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-weekly-report-button", maxSwipes: 12),
                      "Weekly reflection should remain reachable below the Life rhythm")
        for identifier in ["life-weekly-days-recorded", "life-weekly-completed-practices"] {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(identifier, maxSwipes: 6))
            XCTAssertEqual(app.descendants(matching: .any)[identifier].firstMatch.label, "1")
        }
        addScreenshotAttachment(named: "Life weekly reflection summary")

        app.buttons["life-weekly-report-button"].firstMatch.auditTap()
        XCTAssertTrue(app.navigationBars["Weekly Report"].waitForExistence(timeout: 8),
                      "The full measured report should open from the reflection card")
        XCTAssertTrue(app.scrollViews["life-weekly-report-scroll"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Last Week"].firstMatch.waitForExistence(timeout: 5),
                      "The detail should preserve the prior-week comparison")
        let percentages = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", #"^[0-9]+%$"#)
        ).allElementsBoundByIndex.compactMap { Int($0.label.dropLast()) }
        XCTAssertTrue(percentages.contains(0), "The empty prior week should measure zero percent")
        XCTAssertTrue(percentages.contains(where: { $0 > 0 }),
                      "Today's seeded completion should produce a measured nonzero current rate")
    }

    func testCompactHeroLayout() throws {
        let states: [(name: String, style: String, category: String?)] = [
            ("Light", "light", nil),
            ("Dark", "dark", nil),
            ("Accessibility XXXL", "dark", "UICTContentSizeCategoryAccessibilityXXXL")
        ]
        for state in states {
            verifyCompactHeroLayout(theme: "desertWarm", style: state.style,
                                      category: state.category, name: state.name)
        }
    }

    func testCompactHeroRemainingThemes() throws {
        let themes = [
            "oceanCool", "forestGreen", "sakuraCalm", "arcticDawn",
            "solarPop", "contourAtlas", "waterLilies"
        ]
        for theme in themes {
            for style in ["light", "dark"] {
                verifyCompactHeroLayout(theme: theme, style: style, name: "\(theme) \(style)")
            }
        }
    }

    private func verifyCompactHeroLayout(theme: String, style: String,
                                         category: String? = nil, name: String) {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-test-theme", theme, "--ui-test-style", style,
            "-morningBriefingDisabled", "YES"
        ]
        if let category {
            configuration.additionalArguments += ["-UIPreferredContentSizeCategoryName", category]
        }
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))

        let hero = app.descendants(matching: .any)[AXID.lifeHeroProgress].firstMatch
        let ring = app.descendants(matching: .any)["life-hero-ring"].firstMatch
        let external = app.descendants(matching: .any)["life-hero-external-progress"].firstMatch
        let remaining = app.descendants(matching: .any)["life-hero-remaining"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10), "\(name): Life hero should load")
        XCTAssertTrue(app.descendants(matching: .any)["life-hero-heading"].firstMatch.exists)
        XCTAssertTrue(remaining.waitForExistence(timeout: 5))
        XCTAssertTrue(remaining.label.contains("2"), "\(name): two of three seeded habits remain")
        XCTAssertTrue(hero.frame.contains(remaining.frame), "\(name): remaining count should fit inside the hero")
        XCTAssertFalse(app.descendants(matching: .any)["life-hero-narrative"].firstMatch.exists)
        XCTAssertFalse(app.buttons["life-hero-checklist-button"].exists)
        XCTAssertFalse(hero.staticTexts["Morning Stretch"].exists,
                       "\(name): habit names belong in the execution list below the hero")
        if category != nil {
            XCTAssertFalse(ring.exists, "\(name): maximum text size should use external progress")
            XCTAssertTrue(external.waitForExistence(timeout: 5))
            XCTAssertTrue(hero.frame.contains(external.frame),
                          "\(name): external progress should fit inside the hero")
        } else {
            XCTAssertTrue(ring.waitForExistence(timeout: 5))
            XCTAssertEqual(ring.frame.width, 104, accuracy: 1,
                           "\(name): normal text should keep the compact 104pt ring")
            XCTAssertEqual(ring.frame.height, ring.frame.width, accuracy: 1)
            XCTAssertTrue(hero.frame.contains(ring.frame), "\(name): ring should fit inside the hero")
            XCTAssertFalse(external.exists)
        }
        VisualAudit.capture("Life compact hero \(name)")
        if !VisualAudit.isEnabled {
            addScreenshotAttachment(named: "Life compact hero \(name)")
        }
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.lifeSectionHabits, maxSwipes: 8),
                      "\(name): Today's Practice should remain reachable below the hero")
    }

    func testSparseTrendKeepsHabitListAndHistoryAccessible() throws {
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.lifeSectionHabits, maxSwipes: 8),
            "Habit list should remain reachable when trend data is sparse"
        )
        XCTAssertTrue(elementExists(AXID.lifeSectionHabits, timeout: 5), "Habits section should remain available")

        let historyButtonID = "habit-heatmap"
        XCTAssertTrue(
            app.scrollToElementIfNeeded(historyButtonID, maxSwipes: 10),
            "Sparse trend state should provide a reachable History action"
        )
        let historyButton = app.buttons[historyButtonID].firstMatch
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5), "History action should exist with sparse trend data")
        historyButton.tap()

        XCTAssertTrue(
            app.navigationBars["Activity Detail"].waitForExistence(timeout: 8),
            "History should open the activity detail route"
        )
    }

    private func expandCompletedSeededHabit() {
        let disclosure = app.buttons["life-completed-toggle"].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-completed-toggle", maxSwipes: 8),
                      "The seeded completed habit should have a reachable disclosure")
        disclosure.auditTap()
        XCTAssertTrue(app.scrollToLifeHabit(named: "Morning Stretch", maxSwipes: 8),
                      "The completed Morning Stretch row should be revealed")
    }

    func testHabitActionsMenuOpensEditSheet() throws {
        expandCompletedSeededHabit()
        XCTAssertTrue(
            app.openLifeHabitActions(named: "Morning Stretch", maxSwipes: 8),
            "Habit actions should open from the seeded habit row"
        )

        let editButton = app.descendants(matching: .any)[AXID.lifeHabitActionEdit].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Edit action should appear in the habit actions menu")
        editButton.tap()

        let nameField = app.textFields[AXID.habitFormName].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Edit habit sheet should appear from the actions menu")
        XCTAssertTrue(
            app.scrollToElementInPrimaryFormIfNeeded(AXID.habitFormReminderTime, maxSwipes: 6),
            "Reminder time picker should appear in the edit habit form"
        )
        XCTAssertTrue(app.dismissModalIfPresent(cancelIdentifiers: [AXID.habitFormCancel]), "Edit habit sheet should dismiss via shared helper")
    }

    func testHabitActionsMenuArchivesHabit() throws {
        expandCompletedSeededHabit()
        let archivedHabitName = "Morning Stretch"
        XCTAssertTrue(
            app.scrollToLifeHabit(named: archivedHabitName, maxSwipes: 8),
            "Seeded habit should exist before archive"
        )

        XCTAssertTrue(
            app.openLifeHabitActions(named: archivedHabitName, maxSwipes: 8),
            "Habit actions should open from the seeded habit row"
        )
        let actionsButton = app.descendants(matching: .any)[AXID.lifeHabitActions(archivedHabitName)].firstMatch

        let archiveButton = app.descendants(matching: .any)[AXID.lifeHabitActionArchive].firstMatch
        XCTAssertTrue(archiveButton.waitForExistence(timeout: 3), "Archive action should appear in the habit actions menu")
        archiveButton.tap()
        let habitRow = app.descendants(matching: .any)[AXID.lifeHabitRow(archivedHabitName)].firstMatch
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: habitRow)
        waitForExpectations(timeout: 5)
    }
}
