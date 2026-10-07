@preconcurrency import XCTest

@MainActor
final class DuoLifeNumericLayoutTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "life" }
    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
    }

    func testNumericHeroAndChartPeriodsAcrossFoldStates() throws {
        guard VisualAudit.isEnabled,
              ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_FOLD"] == "1" else {
            throw XCTSkip("Opt-in fold and native numeric layout audit only")
        }
        executionTimeAllowance = 600
        for state in ["closed", "partiallyOpen", "openFlat"] {
            VisualAudit.capture("FOLD:\(state)")
            let percentage = app.staticTexts["33%"].firstMatch
            // The ring is a child of a combined accessibility label, not a
            // separate hit target. Check its visible frame, not hit testing.
            let rootScroll = app.scrollViews.firstMatch
            for _ in 0..<16 where !(percentage.exists
                                   && app.windows.firstMatch.frame.insetBy(dx: 2, dy: 2).contains(percentage.frame)) {
                if percentage.exists && percentage.frame.midY < rootScroll.frame.midY { rootScroll.swipeDown() }
                else { rootScroll.swipeUp() }
            }
            XCTAssertTrue(percentage.exists, "Seeded progress should exist after \(state)")
            XCTAssertEqual(percentage.label, "33%", "Folding should preserve the seeded progress")
            XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: 2, dy: 2).contains(percentage.frame),
                          "The whole progress text should fit in the \(state) window")
            // Accessibility can expose the complete label even when pixels are
            // truncated. Host native captures remain a separate visual gate.
            VisualAudit.capture("Life \(state) full progress percentage")
            let progressTextHeight = percentage.frame.height
            for period in ["Weekly", "Monthly"] {
                let control = app.buttons[period].firstMatch
                let scroll = app.scrollViews.firstMatch
                for _ in 0..<16 where !(control.exists && control.isHittable
                                       && app.windows.firstMatch.frame.contains(control.frame)) {
                    if control.exists && control.frame.midY < scroll.frame.midY {
                        scroll.swipeDown()
                    } else {
                        scroll.swipeUp()
                    }
                }
                XCTAssertTrue(control.exists && control.isHittable,
                              "\(period) control should be reachable after \(state)")
                XCTAssertTrue(app.windows.firstMatch.frame.contains(control.frame),
                              "The whole \(period) control should fit in the \(state) window")
                control.auditTap()
                XCTAssertTrue(control.isSelected, "\(period) should become the selected chart period")
                // The chart container's identifier is inherited by its text in
                // SwiftUI's AX tree; retain the exact complete heading query.
                let heading = app.staticTexts.matching(
                    NSPredicate(format: "label == %@", "Completion Rate")
                ).firstMatch
                for _ in 0..<16 where !(heading.exists
                                       && app.windows.firstMatch.frame.insetBy(dx: 2, dy: 2).contains(heading.frame)) {
                    if heading.exists && heading.frame.midY < scroll.frame.midY { scroll.swipeDown(velocity: .slow) }
                    else { scroll.swipeUp(velocity: .slow) }
                }
                XCTAssertEqual(heading.label, "Completion Rate", "The chart heading should retain its complete label")
                XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: 2, dy: 2).contains(heading.frame),
                              "The chart heading should fit wholly in the \(state) window")
                XCTAssertLessThanOrEqual(heading.frame.height, progressTextHeight * 4,
                                        "The chart heading should wrap as words, not individual characters")
                VisualAudit.capture("Life \(state) \(period) chart upper viewport")
                scroll.swipeUp(velocity: .slow)
                VisualAudit.capture("Life \(state) \(period) chart lower viewport")
            }
        }
    }

    func testInnerChartLowerAxesAtMaximumTextSize() throws {
        guard VisualAudit.isEnabled,
              ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_FOLD"] == "1" else {
            throw XCTSkip("Opt-in Book/Open native chart-axis audit only")
        }
        executionTimeAllowance = 600
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 8), "Life should expose its root scroll viewport")

        for state in ["partiallyOpen", "openFlat"] {
            VisualAudit.capture("FOLD:\(state)")
            for period in ["Weekly", "Monthly"] {
                let control = app.buttons[period].firstMatch
                for attempt in 0..<16 {
                    let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 48)
                    if control.exists && viewport.contains(control.frame) && control.isHittable { break }
                    let firstControl = state == "partiallyOpen" && period == "Weekly"
                    let moveUp = control.exists ? control.frame.midY >= viewport.midY
                        : (attempt < 8 ? firstControl : !firstControl)
                    let startY: CGFloat = moveUp ? 0.72 : 0.28
                    let endY: CGFloat = moveUp ? 0.47 : 0.53
                    scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                        .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                            withNormalizedOffset: CGVector(dx: 0.5, dy: endY)
                        ), withVelocity: .slow, thenHoldForDuration: 0.2)
                }
                let controlViewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 48)
                XCTAssertTrue(control.exists && control.isHittable && controlViewport.contains(control.frame),
                              "The whole \(period) control should be selectable in \(state)")
                control.auditTap()
                XCTAssertTrue(control.isSelected, "\(period) should become selected in \(state)")

                // This Other is the actual chart bounding box; the heading and
                // segmented control share its identifier but have different AX types.
                let chart = app.otherElements["habit-completion-chart"].firstMatch
                XCTAssertTrue(chart.waitForExistence(timeout: 8), "\(period) chart should render in \(state)")
                for _ in 0..<16 {
                    let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
                    if chart.frame.maxY <= viewport.maxY - 48
                        && chart.frame.maxY - 96 >= viewport.minY { break }
                    let moveUp = chart.frame.maxY > viewport.maxY - 48
                    let startY: CGFloat = moveUp ? 0.72 : 0.28
                    let endY: CGFloat = moveUp ? 0.47 : 0.53
                    scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                        .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                            withNormalizedOffset: CGVector(dx: 0.5, dy: endY)
                        ), withVelocity: .slow, thenHoldForDuration: 0.2)
                }
                let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
                let frame = chart.frame
                XCTAssertGreaterThan(frame.width, 0, "The \(period) chart should have a rendered width")
                XCTAssertGreaterThan(frame.height, 0, "The \(period) chart should have a rendered height")
                XCTAssertLessThanOrEqual(frame.maxY, viewport.maxY - 48,
                                         "The \(period) date axis should clear the lower viewport by 48 points")
                XCTAssertGreaterThanOrEqual(frame.maxY - viewport.minY, 96,
                                            "At least the final 96 points of the \(period) chart should be visible")
                let horizontalWindow = app.windows.firstMatch.frame.insetBy(dx: 4, dy: 0)
                XCTAssertGreaterThanOrEqual(frame.minX, horizontalWindow.minX,
                                            "The \(period) chart should remain inside the left window edge")
                XCTAssertLessThanOrEqual(frame.maxX, horizontalWindow.maxX,
                                         "The \(period) chart should remain inside the right window edge")
                VisualAudit.capture("Life \(state) \(period) inner chart lower axis with 48pt clearance")
            }
        }
    }
}

/// Completes the Life routes that the existing visual tests only open or expose.
@MainActor
final class DuoLifeArchiveRestoreTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "life" }
    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
    }

    func testArchivedHabitRestoresToActiveLifeList() throws {
        let name = "Morning Stretch"
        XCTAssertTrue(app.openLifeHabitActions(named: name, maxSwipes: 8),
                      "Seeded habit actions should be reachable")
        XCTAssertTrue(app.waitAndTap(AXID.lifeHabitActionArchive), "Archive should accept the seeded habit")

        let archivedLink = AXID.lifeArchivedHabitsLink
        let identifiedLink = app.descendants(matching: .any)[archivedLink].firstMatch
        // The Life section's identifier can be inherited by this NavigationLink;
        // use the same localized-label fallback as the existing management audit.
        let link = identifiedLink.exists ? identifiedLink : app.buttons.matching(
            NSPredicate(format: "label ENDSWITH %@", "archived habits")
        ).firstMatch
        let rootScroll = app.scrollViews.firstMatch
        for _ in 0..<16 where !(link.exists && link.isHittable
                               && app.windows.firstMatch.frame.contains(link.frame)) {
            if link.exists && link.frame.midY < rootScroll.frame.midY { rootScroll.swipeDown() }
            else { rootScroll.swipeUp() }
        }
        XCTAssertTrue(link.exists && link.isHittable,
                      "Archived habits entry should be reachable after archiving")
        assertWholeFrameVisible(link, in: app.windows.firstMatch.frame, "Archived habits entry")
        VisualAudit.capture("Life archived habit link before management")
        link.auditTap()

        let management = app.descendants(matching: .any)[AXID.habitManagementScreen].firstMatch
        XCTAssertTrue(management.waitForExistence(timeout: 8), "Habit management should open")
        VisualAudit.capture("Habit management active upper viewport")
        let archivedFilter = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Archived")).firstMatch
        XCTAssertTrue(archivedFilter.waitForExistence(timeout: 5), "Archived filter should exist")
        assertWholeFrameVisible(archivedFilter, in: app.windows.firstMatch.frame, "Archived filter")
        archivedFilter.auditTap()

        let restoreID = AXID.habitManagementRestore(name)
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(restoreID, maxSwipes: 10),
                      "Restore control should be reachable for the seeded habit")
        let restore = app.buttons[restoreID].firstMatch
        assertWholeFrameVisible(restore, in: app.windows.firstMatch.frame, "Restore control")
        VisualAudit.capture("Habit management archived with Restore control")
        restore.auditTap()

        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: restore)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 8), .completed,
                       "Restored habit should leave the archived filter")
        XCTAssertTrue(app.staticTexts["No Archived Habits"].firstMatch.waitForExistence(timeout: 5),
                      "The archived filter should now be empty")
        VisualAudit.capture("Habit management archived after Restore")

        let activeFilter = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Active")).firstMatch
        XCTAssertTrue(activeFilter.waitForExistence(timeout: 5), "Active filter should exist")
        activeFilter.auditTap()
        XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 8),
                      "The restored habit should appear in the active management list")
        VisualAudit.capture("Habit management active after Restore")

        // A retained root in the AX tree does not prove that management closed.
        let floatingBack = app.buttons["BackButton"].firstMatch
        let back = floatingBack.exists ? floatingBack : app.navigationBars["Habits"].buttons["Life"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Life back navigation should be available")
        back.auditTap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: management)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 8), .completed,
                       "Habit management should close before verifying the restored root row")
        XCTAssertTrue(app.openLifeHabitActions(named: name, maxSwipes: 16),
                      "Restored habit should be actionable again on the Life root")
        VisualAudit.capture("Life restored habit on root list")
    }

    private func assertWholeFrameVisible(_ element: XCUIElement, in viewport: CGRect, _ label: String) {
        XCTAssertTrue(element.exists && element.isHittable, "\(label) should be hittable")
        XCTAssertTrue(viewport.insetBy(dx: 2, dy: 2).contains(element.frame),
                      "\(label) should fit wholly inside the window: \(element.frame), \(viewport)")
    }
}

@MainActor
final class DuoLifeStarterTemplateTests: UITestBaseCase {
    override var initialTabSelectionArgument: String? { "life" }
    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
    }

    func testEmptyStarterTemplateCreatesHabitAndRendersHabitsSection() throws {
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("life-empty-template", maxSwipes: 8),
                      "The empty starter template entry should be reachable")
        VisualAudit.capture("Life empty starter before template")
        app.buttons["life-empty-template"].firstMatch.auditTap()

        let templateList = app.scrollViews["habit-template-list"].firstMatch
        XCTAssertTrue(templateList.waitForExistence(timeout: 8), "Habit template picker should open")
        VisualAudit.capture("Habit template picker upper viewport")
        let finalTemplate = templateList.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Connect with Friends")
        ).firstMatch
        for _ in 0..<12 where !(finalTemplate.exists && finalTemplate.isHittable
                              && templateList.frame.intersection(app.windows.firstMatch.frame).contains(finalTemplate.frame)) {
            templateList.swipeUp()
        }
        XCTAssertTrue(finalTemplate.exists && finalTemplate.isHittable,
                      "The final template category should remain reachable at maximum text size")
        XCTAssertTrue(templateList.frame.intersection(app.windows.firstMatch.frame).contains(finalTemplate.frame),
                      "The lower template control should fit in the visible picker")
        VisualAudit.capture("Habit template picker lower viewport")
        // Template cards currently have no dedicated identifier; their accessible
        // button label includes the localized template name and frequency.
        let vitamins = templateList.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Take Vitamins")
        ).firstMatch
        for _ in 0..<12 where !(vitamins.exists && vitamins.isHittable
                              && templateList.frame.intersection(app.windows.firstMatch.frame).contains(vitamins.frame)) {
            templateList.swipeDown()
        }
        XCTAssertTrue(vitamins.exists && vitamins.isHittable, "Take Vitamins template should be selectable")
        XCTAssertTrue(templateList.frame.intersection(app.windows.firstMatch.frame).contains(vitamins.frame),
                      "The whole template card should fit in the visible picker")
        VisualAudit.capture("Habit template Take Vitamins card")
        vitamins.auditTap()

        let nameField = app.textFields[AXID.habitFormName].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 8), "Template should open a prefilled habit form")
        XCTAssertEqual(nameField.value as? String, "Take Vitamins", "Template name should populate the form")
        let save = app.buttons[AXID.habitFormSave].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5) && save.isEnabled,
                      "The prefilled template should be saveable")
        VisualAudit.capture("Prefilled Take Vitamins habit form")
        save.auditTap()

        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: nameField)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 8), .completed,
                       "Saving should dismiss the template form")
        XCTAssertTrue(app.descendants(matching: .any)[AXID.lifeSectionHabits].firstMatch.waitForExistence(timeout: 8),
                      "The new habits section should render")
        XCTAssertFalse(app.buttons["life-empty-template"].exists,
                       "Creating the first habit should replace the empty starter")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.lifeHabitActions("Take Vitamins"), maxSwipes: 10),
                      "Created template habit should render with a usable action control")
        let actions = app.buttons[AXID.lifeHabitActions("Take Vitamins")].firstMatch
        XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: 2, dy: 2).contains(actions.frame),
                      "Created habit control should fit inside the window")
        VisualAudit.capture("Life habits section after template creation")
    }
}
