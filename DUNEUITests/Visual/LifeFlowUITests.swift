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
    }

    func testCaptureL01AndPastRecordLightDarkAndMaximumAX() {
        for (style, maximumAX) in [("light", false), ("dark", false), ("dark", true)] {
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
            capture("L-P01-Past-Record-form-\(suffix)")
        }
    }
}
