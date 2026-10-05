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
        XCTAssertTrue(firstRow.label.contains("Completed"), "Seeded Morning Stretch history should show its completion")

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
