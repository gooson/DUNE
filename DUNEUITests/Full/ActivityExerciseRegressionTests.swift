@preconcurrency import XCTest
import UIKit

@MainActor
final class ActivityExerciseRegressionTests: ActivityExerciseSeededUITestBaseCase {
    private enum Fixture {
        static let benchPressID = "barbell-bench-press"
        static let benchPressLocalizedName = "바벨 벤치프레스"
        static let deadliftID = "conventional-deadlift"
        static let manualStrengthTypeKey = "manual-strength"
        static let runningID = "running"
        static let singleTemplate = "Codex Strength Starter"
        static let updatedTemplate = "Codex Strength Updated"
        static let circuitTemplate = "Codex Circuit Builder"
        static let createdTemplate = "Codex Builder Template"
        static let customExercise = "Codex Planner Move"
        static let createdCategory = "Codex Recovery"
        static let notificationWorkoutRouteTitle = "Workout Detail Route"
        static let notificationMissingRouteTitle = "Missing Workout Route"
        static let notificationWorkoutRouteID = "ui-test-activity-workout-running"
        static let notificationMissingRouteID = "ui-test-activity-workout-missing"
    }

    func testWeeklyStatsValuesAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-section-weeklystats", maxSwipes: 12))
        let scroll = app.scrollViews["activity-root-scroll"].firstMatch
        XCTAssertTrue(scroll.exists)
        for stat in ["volume", "calories", "duration", "activeDays"] {
            let value = app.staticTexts["activity-weekly-stat-value-\(stat)"].firstMatch
            for _ in 0..<12 {
                let viewport = scroll.frame.intersection(app.windows.firstMatch.frame)
                if value.exists && viewport.contains(value.frame) { break }
                if value.exists && value.frame.midY < viewport.midY {
                    scroll.swipeDown(velocity: .slow)
                } else {
                    scroll.swipeUp(velocity: .slow)
                }
            }
            XCTAssertTrue(value.exists, "Seeded weekly \(stat) should render")
            XCTAssertFalse(value.label.isEmpty)
            XCTAssertTrue(scroll.frame.intersection(app.windows.firstMatch.frame).contains(value.frame),
                          "The full weekly \(stat) value should fit in the scroll viewport")
            VisualAudit.capture("Weekly \(stat) value at maximum accessibility size")
        }
    }

    func testVisualAuditWorkoutInsights() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        try verifyWorkoutInsightsReturnsToWorkout(useQuickStart: true)
    }

    func testVisualAuditWorkoutInsightsSheetFallback() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-design-map-insights-sheet")
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        openQuickStartPicker()
        startQuickStartExerciseFromDetail(search: "Bench Press", exerciseID: Fixture.benchPressID)
        XCTAssertTrue(app.waitAndTapToolbarAction("workout-session-insights"))
        XCTAssertTrue(app.descendants(matching: .any)["activity-weeklystats-detail-screen"].firstMatch
            .waitForExistence(timeout: 10), "Workout Insights sheet should open on iPad")
        VisualAudit.capture("Workout Insights iPad sheet fallback")
    }

    func testWorkoutInsightsReturnsToInteractiveWorkoutAtMaximumAccessibilityTextSize() throws {
        if VisualAudit.isEnabled { executionTimeAllowance = 420 }
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        try verifyWorkoutInsightsReturnsToWorkout(useQuickStart: true, checkPeriodMenu: true)
    }

    func testLegacyPhoneInsightsContentRecoversPrimaryWorkoutUI() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-legacy-insights-content")
        launchApp(with: configuration)
        XCTAssertTrue(app.descendants(matching: .any)["legacy-insights-recovered"].firstMatch
            .waitForExistence(timeout: 8), "The legacy scene content must recover the phone UI")
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        XCTAssertFalse(app.buttons["workout-insights-close"].firstMatch.exists,
                       "A recovered phone scene must not depend on unsupported window closing")
        openQuickStartPicker()
        startQuickStartExerciseFromDetail(search: "Bench Press", exerciseID: Fixture.benchPressID)
        XCTAssertTrue(scrollToWorkoutControl(AXID.workoutSessionField("kg")))
        let weight = app.textFields[AXID.workoutSessionField("kg")].firstMatch
        let original = try XCTUnwrap(Double(weight.value as? String ?? ""))
        XCTAssertTrue(scrollToWorkoutControl("+2.5"))
        app.buttons["+2.5"].firstMatch.auditTap()
        XCTAssertEqual(try XCTUnwrap(Double(weight.value as? String ?? "")), original + 2.5, accuracy: 0.01)
        VisualAudit.capture("Recovered legacy phone scene accepts workout input")
        XCUIDevice.shared.press(.home)
        configuration.resetState = false
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        openExerciseViewFromRecentWorkouts(maxSwipes: 24)
        let resume = app.buttons["exercise-resume-draft"].firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 8), "Recovery must retain the persisted workout draft")
        resume.auditTap()
        let start = app.buttons[AXID.exerciseStartButton].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 8), "Resume must offer the exercise start screen")
        start.auditTap()
        XCTAssertTrue(scrollToWorkoutControl(AXID.workoutSessionField("kg")))
        XCTAssertEqual(try XCTUnwrap(Double(app.textFields[AXID.workoutSessionField("kg")]
            .firstMatch.value as? String ?? "")), original + 2.5, accuracy: 0.01)
        VisualAudit.capture("Recovered legacy phone content resumes persisted workout draft")
    }

    private func verifyWorkoutInsightsReturnsToWorkout(useQuickStart: Bool = false, checkPeriodMenu: Bool = false) throws {
        if useQuickStart {
            openQuickStartPicker()
        } else {
            openExerciseSingleExercisePicker()
        }
        startQuickStartExerciseFromDetail(search: "Bench Press", exerciseID: Fixture.benchPressID)
        XCTAssertTrue(app.waitAndTapToolbarAction("workout-session-insights"))
        XCTAssertTrue(
            app.descendants(matching: .any)["activity-weeklystats-detail-screen"].firstMatch.waitForExistence(timeout: 10),
            "Workout Insights should show the weekly statistics content"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["activity-weeklystats-summary-grid"].firstMatch
                .waitForExistence(timeout: 10),
            "Insights must load advanced mock statistics before checking window return"
        )
        XCTAssertFalse(app.staticTexts["Unable to load data."].exists)
        VisualAudit.capture("Workout Insights presentation")
        captureFunctionalCheckpoint("Insights loaded at maximum accessibility size")
        if useQuickStart {
            let statsScroll = app.scrollViews["activity-weeklystats-detail-screen"].firstMatch
            let chartHeading = statsScroll.staticTexts["weeklystats-chart-heading"].firstMatch
            let metricPicker = statsScroll.buttons["weeklystats-chart-metric-picker"].firstMatch
            let window = app.windows.firstMatch
            let close = app.buttons["workout-insights-close"].firstMatch
            XCTAssertTrue(statsScroll.exists && window.exists && close.exists,
                          "Insights should expose its own scroll, window, and native close action")
            XCTAssertTrue(chartHeading.waitForExistence(timeout: 5) && metricPicker.waitForExistence(timeout: 5),
                          "The daily chart should expose both heading and metric menu")

            func visibleContent() -> CGRect {
                let scrollFrame = statsScroll.frame.intersection(window.frame)
                var top = scrollFrame.minY
                var bottom = scrollFrame.maxY
                let navigation = app.navigationBars.firstMatch
                if navigation.exists && navigation.frame.minY < scrollFrame.midY && navigation.frame.maxY > top {
                    top = min(bottom, navigation.frame.maxY)
                }
                if close.isHittable && close.frame.midY > scrollFrame.midY && close.frame.minY < bottom {
                    bottom = max(top, close.frame.minY)
                }
                return CGRect(x: scrollFrame.minX + 4, y: top + 4,
                              width: max(0, scrollFrame.width - 8), height: max(0, bottom - top - 8))
            }

            if checkPeriodMenu {
                let period = statsScroll.buttons["weeklystats-period-picker"].firstMatch
                XCTAssertTrue(period.waitForExistence(timeout: 10) && period.isHittable,
                              "The maximum-text period menu must be reachable")
                XCTAssertGreaterThanOrEqual(period.frame.width, 44)
                XCTAssertGreaterThanOrEqual(period.frame.height, 44)
                XCTAssertTrue(visibleContent().contains(period.frame),
                              "The complete period menu must fit the visible Insights viewport")
                let range = statsScroll.descendants(matching: .any)["activity-weeklystats-previous-period"].firstMatch
                XCTAssertTrue(range.waitForExistence(timeout: 10), "The seeded comparison must expose its date range")
                let initialRange = range.label
                XCTAssertFalse(initialRange.isEmpty)
                let choices: [(id: String, names: [String])] = [
                    ("Last Week", ["Last Week", "지난 주", "先週"]),
                    ("This Month", ["This Month", "이번 달", "今月"]),
                    ("This Week", ["This Week", "이번 주", "今週"])
                ]
                XCTAssertTrue(["This Week", "이번 주", "今週"].contains(period.value as? String ?? ""),
                              "The selected period must expose the complete translated label")
                VisualAudit.capture("Weekly stats maximum AX period menu")
                addScreenshotAttachment(named: "Weekly stats maximum AX period menu")
                var previousRange = initialRange
                for choice in choices {
                    period.auditTap()
                    let option = app.buttons["weeklystats-period-option-\(choice.id)"].firstMatch
                    XCTAssertTrue(option.waitForExistence(timeout: 5) && option.isHittable,
                                  "The period menu must expose \(choice.id)")
                    let selectedLabel = option.label
                    XCTAssertTrue(choice.names.contains(selectedLabel), "The menu option must show its complete label")
                    option.auditTap()
                    let changed = XCTNSPredicateExpectation(
                        predicate: NSPredicate(format: "exists == true AND label != '' AND label != %@", previousRange),
                        object: range
                    )
                    XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed,
                                   "Selecting a period must change the actual comparison range")
                    XCTAssertEqual(period.value as? String, selectedLabel,
                                   "The selected period must expose the same complete translated label")
                    XCTAssertTrue(period.isHittable && visibleContent().contains(period.frame),
                                  "The selected menu must remain fully visible")
                    VisualAudit.capture("Weekly stats maximum AX period \(choice.id)")
                    addScreenshotAttachment(named: "Weekly stats maximum AX period \(choice.id)")
                    previousRange = range.label
                }
                XCTAssertEqual(range.label, initialRange, "Returning to This Week must restore its comparison range")
            }

            for _ in 0..<8 {
                let viewport = visibleContent()
                let chartControls = chartHeading.frame.union(metricPicker.frame)
                if viewport.contains(chartControls) && chartHeading.isHittable && metricPicker.isHittable {
                    break
                }
                let displacement: CGFloat
                if chartControls.minY < viewport.minY {
                    displacement = min(max(viewport.minY - chartControls.minY + 12, 44), viewport.height * 0.35)
                } else if chartControls.maxY > viewport.maxY {
                    displacement = -min(max(chartControls.maxY - viewport.maxY + 12, 44), viewport.height * 0.35)
                } else {
                    break
                }
                let origin = statsScroll.frame.origin
                let start = statsScroll.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: viewport.midX - origin.x, dy: viewport.midY - origin.y))
                let end = statsScroll.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: viewport.midX - origin.x,
                                         dy: viewport.midY + displacement - origin.y))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            let chartControls = chartHeading.frame.union(metricPicker.frame)
            XCTAssertTrue(visibleContent().contains(chartControls),
                          "The complete chart heading and menu must share the visible scroll viewport")
            XCTAssertTrue(chartHeading.isHittable && metricPicker.isHittable,
                          "The chart title and metric menu must both be reachable at maximum accessibility size")
            XCTAssertLessThanOrEqual(chartHeading.frame.maxY, metricPicker.frame.minY,
                                     "The chart title must remain above its metric menu")
            addScreenshotAttachment(named: "Daily chart heading and accessible metric menu")
            VisualAudit.capture("Daily chart heading and accessible metric menu")
            metricPicker.auditTap()
            let volume = app.buttons.matching(NSPredicate(
                format: "label IN %@", ["Volume (kg)", "볼륨 (kg)", "ボリューム (kg)"]
            )).firstMatch
            XCTAssertTrue(volume.waitForExistence(timeout: 5) && volume.isHittable,
                          "The chart menu must expose the complete volume label")
            VisualAudit.capture("Daily chart metric choices")
            volume.auditTap()
            XCTAssertTrue(metricPicker.label.contains("kg"),
                          "Selecting volume must update the chart metric")
            VisualAudit.capture("Daily volume chart after selecting volume")
        }
        for index in 1...3 {
            if app.scrollViews.firstMatch.exists { app.scrollViews.firstMatch.swipeUp(velocity: .slow) }
            VisualAudit.capture("Workout Insights lower viewport \(index)")
            captureFunctionalCheckpoint("Insights lower viewport \(index)")
        }
        let close = app.buttons["workout-insights-close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5) && close.isHittable,
                      "Insights must have a usable close action after scrolling")
        close.auditTap()
        let closeDisappeared = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: close
        )
        XCTAssertEqual(XCTWaiter.wait(for: [closeDisappeared], timeout: 10), .completed,
                       "The Insights window must close; a workout in a background window is insufficient")
        let controls = app.scrollViews["workout-session-controls"].firstMatch
        XCTAssertTrue(controls.waitForExistence(timeout: 10) && controls.isHittable,
                      "Closing Insights must return to the active workout")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.workoutSessionCompleteSet, maxSwipes: 8),
                      "The resumed workout must accept interaction")
        captureFunctionalCheckpoint("Workout interactive after closing Insights")
    }

    func testVisualAuditTemplateFromActivityPicker() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        XCTAssertTrue(app.waitAndTapToolbarAction(AXID.activityToolbarAdd))
        let row = app.buttons["picker-template-33333333-3333-4333-8333-333333333333"].firstMatch
        for _ in 0..<10 where !(row.exists && row.isHittable) {
            app.tables[AXID.pickerRootList].firstMatch.swipeUp(velocity: .slow)
        }
        VisualAudit.capture("Activity template picker row")
        XCTAssertTrue(row.exists && row.isHittable)
        row.auditTap()
        let start = app.buttons[AXID.templateWorkoutTransitionStart].firstMatch
        // The transition advances automatically after five seconds, including
        // time spent waiting for the host to capture the picker dismissal.
        if start.exists && start.isHittable {
            start.auditTap()
        }
        XCTAssertTrue(
            app.scrollViews["workout-session-controls"].firstMatch.waitForExistence(timeout: 10),
            "Selecting an Activity template should enter its workout"
        )
        VisualAudit.capture("Template session")
    }

    func testTemplateEntryDefaultsRemainEditableAtMaximumAccessibilityTextSize() throws {
        let textSizeArguments = [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: textSizeArguments)
        launchApp(with: configuration)
        XCTAssertEqual(Array(app.launchArguments.suffix(2)), textSizeArguments)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))

        openTemplateList()
        openSeededSingleTemplateEditor()

        let sets = app.steppers.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
            "template-entry-", "-sets"
        )).firstMatch
        let form = app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch
        for _ in 0..<12 where !sets.exists { form.swipeUp(velocity: .slow) }
        XCTAssertTrue(sets.waitForExistence(timeout: 5), "Seeded entry should expose its sets stepper")
        let entryID = String(sets.identifier.dropFirst("template-entry-".count).dropLast("-sets".count))
        XCTAssertNotNil(UUID(uuidString: entryID), "Entry controls should share a UUID-based identifier")

        let prefix = "template-entry-\(entryID)-"
        let reps = app.steppers["\(prefix)reps"].firstMatch
        let weight = app.textFields["\(prefix)weight"].firstMatch
        let rest = app.buttons["\(prefix)rest"].firstMatch
        for (identifier, control) in [
            ("sets", sets), ("reps", reps), ("weight", weight), ("rest", rest)
        ] {
            XCTAssertTrue(
                app.scrollToHittableElementIfNeeded("\(prefix)\(identifier)", maxSwipes: 12),
                "\(identifier) must be reachable at maximum accessibility text size"
            )
            XCTAssertTrue(control.isHittable, "\(identifier) must be tappable")
            VisualAudit.capture("Template entry \(identifier) reachable at maximum accessibility text size")
        }

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("\(prefix)sets", maxSwipes: 12, direction: .down))
        let setsIncrement = app.buttons["\(prefix)sets-Increment"].firstMatch
        XCTAssertTrue(setsIncrement.isHittable, "Sets increment must be reachable")
        setsIncrement.auditTap()

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("\(prefix)reps", maxSwipes: 12))
        let repsIncrement = app.buttons["\(prefix)reps-Increment"].firstMatch
        XCTAssertTrue(repsIncrement.isHittable, "Reps increment must be reachable")
        repsIncrement.auditTap()

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("\(prefix)rest", maxSwipes: 12))
        rest.auditTap()
        let ninetySeconds = app.descendants(matching: .any).matching(NSPredicate(
            format: "label IN %@", ["90s", "90초", "90秒"]
        )).firstMatch
        XCTAssertTrue(ninetySeconds.waitForExistence(timeout: 5), "Rest menu should offer 90 seconds")
        let selectedRestLabel = ninetySeconds.label
        ninetySeconds.auditTap()

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("\(prefix)weight", maxSwipes: 12, direction: .down))
        XCTAssertTrue(app.fillTextInput("\(prefix)weight", with: "65"), "Weight should accept an edited value")
        XCTAssertEqual(weight.value as? String, "65")
        let keyboardDone = app.buttons["template-form-keyboard-done"].firstMatch
        XCTAssertTrue(keyboardDone.waitForExistence(timeout: 3) && keyboardDone.isHittable)
        keyboardDone.auditTap()

        let save = app.buttons[AXID.templateFormSave].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5) && save.isEnabled, "Edited template should be saveable")
        save.auditTap()
        XCTAssertTrue(app.buttons[AXID.workoutTemplateRow(Fixture.singleTemplate)].firstMatch.waitForExistence(timeout: 8))

        openSeededSingleTemplateEditor()
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("\(prefix)weight", maxSwipes: 12),
                      "Saved weight should remain reachable")
        XCTAssertTrue(weight.waitForExistence(timeout: 5), "Saved entry should retain its identifier")
        XCTAssertEqual(weight.value as? String, "65", "Edited weight should persist after reopening")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("\(prefix)rest", maxSwipes: 12))
        let savedRest = [rest.label, rest.value as? String ?? ""].joined(separator: " ")
        XCTAssertTrue(savedRest.contains(selectedRestLabel),
                      "Edited rest duration should persist after reopening (actual: \(savedRest))")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("\(prefix)sets", maxSwipes: 12, direction: .down))
        XCTAssertTrue(sets.label.contains("3") || (sets.value as? String)?.contains("3") == true,
                      "Edited sets should persist after reopening")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("\(prefix)reps", maxSwipes: 12))
        XCTAssertTrue(reps.label.contains("9") || (reps.value as? String)?.contains("9") == true,
                      "Edited reps should persist after reopening")
    }

    func testVisualAuditWorkoutPreservesInputsAcrossFoldStates() throws {
        guard VisualAudit.isEnabled,
              ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_FOLD"] == "1" else {
            throw XCTSkip("Opt-in fold continuity audit only")
        }
        // Real Device Hub transitions include host capture handshakes.
        // Keep the larger allowance confined to this opt-in diagnostic case.
        executionTimeAllowance = 600
        try verifyWorkoutDraftAndRest(performFoldTransitions: true, foldPhase: .draft)
    }

    func testVisualAuditRestTimerAcrossFoldStates() throws {
        guard VisualAudit.isEnabled,
              ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_FOLD"] == "1" else {
            throw XCTSkip("Opt-in fold continuity audit only")
        }
        executionTimeAllowance = 600
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-fold-audit-long-rest")
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        try verifyWorkoutDraftAndRest(performFoldTransitions: true, foldPhase: .rest)
    }

    func testWorkoutDraftAndRestTimerAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        try verifyWorkoutDraftAndRest(performFoldTransitions: false, expectsAutomaticInputScroll: true)
    }

    func testWorkoutDraftAcrossRotationAtDefaultTextSize() throws {
        try verifyWorkoutDraftAcrossRotation(contentSize: "UICTContentSizeCategoryL")
    }

    func testTrainingVolumeSummaryAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        let contentID = "activity-section-volume-content"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(contentID, maxSwipes: 24))
        let card = app.buttons[contentID].firstMatch
        let viewport = app.scrollViews[AXID.activityRootScroll].firstMatch.frame
            .intersection(app.windows.firstMatch.frame)
        XCTAssertTrue(card.exists && card.isHittable)
        XCTAssertTrue(viewport.contains(CGPoint(x: card.frame.midX, y: card.frame.midY)))
        VisualAudit.capture("Maximum AX training volume summary labels")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.activitySectionVolume,
                                                         maxSwipes: 8, direction: .down))
        app.buttons[AXID.activitySectionVolume].firstMatch.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityTrainingVolumeDetailScreen]
            .firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityTrainingVolumeOverview]
            .firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["activity-training-volume-current-active-days"]
            .firstMatch.waitForExistence(timeout: 15))
        VisualAudit.capture("Maximum AX training volume detail overview")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-training-volume-previous-period", maxSwipes: 8))
        VisualAudit.capture("Maximum AX training volume previous comparison")
    }

    func testExerciseHistoryAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        openExerciseViewFromRecentWorkouts(maxSwipes: 24)
        VisualAudit.capture("Maximum AX complete suggested exercise names")
        let list = app.collectionViews[AXID.exerciseViewScreen].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "The exercise history collection must exist")
        let benchPressRow = app.descendants(matching: .any)[AXID.exerciseRow(Fixture.benchPressID)].firstMatch
        var sawBenchPress = benchPressRow.exists
        for index in 1...3 {
            list.swipeUp(velocity: .slow)
            sawBenchPress = sawBenchPress || benchPressRow.exists
            VisualAudit.capture("Maximum AX workout history full names and metrics \(index)")
        }
        XCTAssertTrue(sawBenchPress, "Scrolling must reveal the seeded Bench Press history row")
    }

    func testWorkoutDraftAcrossRotationAtMaximumAccessibilityTextSize() throws {
        try verifyWorkoutDraftAcrossRotation(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
    }

    private func verifyWorkoutDraftAcrossRotation(contentSize: String) throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: ["-UIPreferredContentSizeCategoryName", contentSize])
        let hostOrientation = VisualAudit.isEnabled
            && ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_HOST_ONLY"] == "1"
            && ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_FOLD"] == "1"
        if hostOrientation { executionTimeAllowance = 600 }
        if !hostOrientation { XCUIDevice.shared.orientation = .portrait }
        defer { XCUIDevice.shared.orientation = .portrait }
        launchApp(with: configuration)
        if hostOrientation { VisualAudit.capture("ORIENT:portrait") }
        openQuickStartPicker()
        startQuickStartExerciseFromDetail(search: "Bench Press", exerciseID: Fixture.benchPressID)
        XCTAssertTrue(scrollToWorkoutControl("+2.5"))
        app.buttons["+2.5"].firstMatch.auditTap()
        XCTAssertTrue(scrollToWorkoutControl("+1"))
        app.buttons["+1"].firstMatch.auditTap()
        let weight = try XCTUnwrap(app.textFields[AXID.workoutSessionField("kg")].firstMatch.value as? String)
        let reps = try XCTUnwrap(app.textFields[AXID.workoutSessionField("reps")].firstMatch.value as? String)
        VisualAudit.capture("Workout portrait before rotation \(contentSize)")
        let window = app.windows.firstMatch
        let initialViewport = window.frame.size
        if hostOrientation {
            VisualAudit.capture("ORIENT:landscapeLeft")
        } else {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        let landscape = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in window.frame.size != initialViewport }, object: window
        )
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 8), .completed,
                       "The active workout viewport must actually rotate")
        assertActiveWorkoutInputsAfterFold(weight: weight, reps: reps)
        VisualAudit.capture("Workout rotated viewport preserves inputs \(contentSize)")
        if hostOrientation {
            VisualAudit.capture("ORIENT:portrait")
        } else {
            XCUIDevice.shared.orientation = .portrait
        }
        let restored = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in window.frame.size == initialViewport }, object: window
        )
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 8), .completed,
                       "Portrait must restore the original workout viewport")
        assertActiveWorkoutInputsAfterFold(weight: weight, reps: reps)
        VisualAudit.capture("Workout portrait after rotation \(contentSize)")
    }

    private enum FoldAuditPhase { case draft, rest }

    private func verifyWorkoutDraftAndRest(
        performFoldTransitions: Bool,
        foldPhase: FoldAuditPhase? = nil,
        expectsAutomaticInputScroll: Bool = false
    ) throws {
        let foldCheckpoints = performFoldTransitions
            ? ["FOLD:partiallyOpen", "FOLD:openFlat", "FOLD:closed"] : []
        // Fold continuity starts from the same toolbar route as the functional
        // check; navigating the long history surface is a separate regression.
        openQuickStartPicker()
        startQuickStartExerciseFromDetail(search: "Bench Press", exerciseID: Fixture.benchPressID)
        let weight = app.textFields[AXID.workoutSessionField("kg")].firstMatch
        let reps = app.textFields[AXID.workoutSessionField("reps")].firstMatch
        XCTAssertTrue(scrollToWorkoutControl(AXID.workoutSessionField("kg")))
        let originalWeight = try XCTUnwrap(Double(weight.value as? String ?? ""))
        XCTAssertTrue(scrollToWorkoutControl("+2.5"))
        app.buttons["+2.5"].firstMatch.auditTap()
        let weightDraft = try XCTUnwrap(weight.value as? String)
        XCTAssertEqual(try XCTUnwrap(Double(weightDraft)), originalWeight + 2.5, accuracy: 0.01)
        XCTAssertTrue(scrollToWorkoutControl(AXID.workoutSessionField("reps")))
        let originalReps = try XCTUnwrap(Int(reps.value as? String ?? ""))
        XCTAssertTrue(scrollToWorkoutControl("+1"))
        app.buttons["+1"].firstMatch.auditTap()
        let repsDraft = try XCTUnwrap(reps.value as? String)
        XCTAssertEqual(try XCTUnwrap(Int(repsDraft)), originalReps + 1)

        assertActiveWorkoutInputsAfterFold(weight: weightDraft, reps: repsDraft)
        if foldPhase != .rest {
            for checkpoint in foldCheckpoints {
                VisualAudit.capture(checkpoint)
                assertActiveWorkoutInputsAfterFold(weight: weightDraft, reps: repsDraft)
            }
        }
        if foldPhase == .draft { return }

        let completeSet = app.buttons[AXID.workoutSessionCompleteSet].firstMatch
        if app.scrollViews["workout-session-controls"].buttons[AXID.workoutSessionCompleteSet].firstMatch.exists {
            XCTAssertTrue(scrollToWorkoutControl(AXID.workoutSessionCompleteSet, mustFitInViewport: true),
                          "The whole current set action should be reachable before completing it")
        }
        XCTAssertTrue(completeSet.waitForExistence(timeout: 5) && completeSet.isHittable)
        completeSet.auditTap()
        assertCompletedSetSummaryDuringRest(weight: weightDraft, reps: repsDraft)

        let addRest = app.buttons["workout-session-add-rest"].firstMatch
        XCTAssertTrue(scrollToWorkoutControl("workout-session-add-rest"),
                      "Rest controls must be reachable in the workout scroll viewport")
        XCTAssertTrue(addRest.waitForExistence(timeout: 5) && addRest.isHittable,
                      "The active rest timer should expose +30s")
        var additions = 0
        while try restCountdownSeconds() < 240 && additions < 12 {
            addRest.tap()
            additions += 1
        }
        var previousSeconds = try restCountdownSeconds()
        XCTAssertGreaterThanOrEqual(previousSeconds, 240, "Rest should be long enough to audit every fold state")
        var previousSampleTime = Date()
        VisualAudit.capture("Rest timer initial after first completed set")
        assertCompletedSetSummaryDuringRest(weight: weightDraft, reps: repsDraft)
        if !performFoldTransitions {
            let countdown = app.staticTexts["workout-session-rest-countdown"].firstMatch
            let initialLabel = countdown.label
            let timerAdvanced = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label != %@", initialLabel), object: countdown
            )
            XCTAssertEqual(XCTWaiter.wait(for: [timerAdvanced], timeout: 8), .completed,
                           "The active rest timer must count down without manual interaction")
            let currentSeconds = try restCountdownSeconds()
            XCTAssertGreaterThan(currentSeconds, 0)
            XCTAssertLessThan(currentSeconds, previousSeconds)
            assertCompletedSetSummaryDuringRest(weight: weightDraft, reps: repsDraft)
        }
        for checkpoint in foldCheckpoints {
            VisualAudit.capture(checkpoint)
            assertCompletedSetSummaryDuringRest(weight: weightDraft, reps: repsDraft)
            let currentSeconds = try restCountdownSeconds()
            let sampleTime = Date()
            let elapsed = sampleTime.timeIntervalSince(previousSampleTime)
            XCTAssertGreaterThan(currentSeconds, 0, "Rest countdown must remain active after folding")
            XCTAssertLessThanOrEqual(currentSeconds, previousSeconds,
                                     "Rest countdown must not reset after folding")
            XCTAssertLessThanOrEqual(
                abs(Double(currentSeconds) - (Double(previousSeconds) - elapsed)), 3,
                "Rest countdown should track elapsed wall time across the fold transition"
            )
            previousSeconds = currentSeconds
            previousSampleTime = sampleTime
            XCTAssertTrue(scrollToWorkoutControl("workout-session-rest-countdown", mustFitInViewport: true),
                          "The running countdown must remain reachable after folding")
            let countdown = app.staticTexts["workout-session-rest-countdown"].firstMatch
            let controls = app.scrollViews["workout-session-controls"].firstMatch
            let visible = controls.frame.intersection(app.windows.firstMatch.frame)
            XCTAssertTrue(visible.contains(countdown.frame),
                          "The full countdown must fit in the active scroll viewport")
            VisualAudit.capture("Full rest countdown after \(checkpoint)")
        }

        let skipRest = app.buttons[AXID.workoutSessionSkipRest].firstMatch
        XCTAssertTrue(scrollToWorkoutControl(AXID.workoutSessionSkipRest),
                      "Rest Skip must be reachable after the viewport changes")
        XCTAssertTrue(skipRest.waitForExistence(timeout: 5) && skipRest.isHittable,
                      "Rest Skip should remain actionable after folding")
        skipRest.auditTap()
        XCTAssertTrue(completeSet.waitForExistence(timeout: 5) && completeSet.isEnabled,
                      "The next set should be actionable after skipping rest")
        VisualAudit.capture("Next set immediately after skipping rest")
        if expectsAutomaticInputScroll {
            let nextInputsViewport = app.scrollViews["workout-session-controls"].firstMatch.frame
                .intersection(app.windows.firstMatch.frame)
            for field in ["kg", "reps"] {
                XCTAssertTrue(nextInputsViewport.contains(app.textFields[AXID.workoutSessionField(field)].firstMatch.frame),
                              "The next-set \(field) value should be fully visible immediately after rest")
            }
        }
        // Seeded later sets may already contain values from an earlier workout.
        // Folding must preserve the active draft; it must not overwrite those
        // existing defaults with the just-completed set.
        for field in ["kg", "reps"] {
            let identifier = AXID.workoutSessionField(field)
            XCTAssertTrue(scrollToWorkoutControl(identifier, mustFitInViewport: true),
                          "The whole next-set \(field) draft should be reachable")
            XCTAssertFalse((app.textFields[identifier].firstMatch.value as? String ?? "").isEmpty,
                           "Next-set \(field) draft should remain usable")
            VisualAudit.capture("Next-set \(field) fully visible after skipping rest")
        }
        let done = app.buttons[AXID.workoutSessionDone].firstMatch
        let controls = app.scrollViews["workout-session-controls"].firstMatch
        for _ in 0..<6 where !done.exists { controls.swipeDown() }
        XCTAssertTrue(done.waitForExistence(timeout: 5) && done.isEnabled,
                      "The completed first set should keep session Done enabled")
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    func testActivityRootShowsPrimaryRegressionAnchors() throws {
        ensureActivityRoot()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityRootScroll].firstMatch.waitForExistence(timeout: 10),
            "Activity root scroll should exist for the seeded surface"
        )
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.activitySectionWeeklyStats, maxSwipes: 4),
            "Weekly stats section should be reachable from the Activity root"
        )
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.activitySectionPR, maxSwipes: 10),
            "Personal records section should be reachable from the Activity root"
        )
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.activitySectionConsistency, maxSwipes: 10),
            "Consistency section should be reachable from the Activity root"
        )
    }

    func testTrainingReadinessDetailShowsTrendAndSubscoreSections() throws {
        if VisualAudit.isEnabled {
            var configuration = launchConfiguration
            configuration.additionalArguments += [
                "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ]
            launchApp(with: configuration)
            XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        }
        openTrainingReadinessDetail()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.trainingReadinessPeriodPicker].firstMatch.waitForExistence(timeout: 15),
            "Training readiness detail should expose the period picker"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.trainingReadinessChartTrend].firstMatch.waitForExistence(timeout: 15),
            "Training readiness detail should render the trend chart"
        )

        tapSegment(in: AXID.trainingReadinessPeriodPicker, index: 1, timeout: 10)

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.trainingReadinessSubscoreHRV].firstMatch.waitForExistence(timeout: 15),
            "HRV subscore chart should appear after leaving day mode"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.trainingReadinessSubscoreRHR].firstMatch.waitForExistence(timeout: 15),
            "RHR subscore chart should appear after leaving day mode"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.trainingReadinessSubscoreSleep].firstMatch.waitForExistence(timeout: 15),
            "Sleep subscore chart should appear after leaving day mode"
        )
        if VisualAudit.isEnabled {
            let scroll = app.scrollViews[AXID.activityTrainingReadinessDetailScreen].firstMatch
            XCTAssertTrue(scroll.waitForExistence(timeout: 5), "Readiness detail should own its scroll viewport")
            for (identifier, checkpoint) in [
                (AXID.trainingReadinessChartTrend, "trend and axes"),
                (AXID.trainingReadinessSubscoreHRV, "HRV subscore"),
                (AXID.trainingReadinessSubscoreRHR, "RHR subscore"),
                (AXID.trainingReadinessSubscoreSleep, "Sleep subscore")
            ] {
                let section = app.descendants(matching: .any)[identifier].firstMatch
                for _ in 0..<14 {
                    let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 8)
                    if section.exists && viewport.contains(CGPoint(x: section.frame.midX, y: section.frame.midY)) { break }
                    if section.exists && section.frame.midY < viewport.midY { scroll.swipeDown(velocity: .slow) }
                    else { scroll.swipeUp(velocity: .slow) }
                }
                let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 8)
                XCTAssertTrue(section.exists && viewport.contains(CGPoint(x: section.frame.midX, y: section.frame.midY)),
                              "Readiness \(checkpoint) should reach the visible viewport")
                VisualAudit.capture("Readiness maximum AX \(checkpoint) viewport")
            }
        }
    }

    func testActivityDetailRoutesOpenExpectedScreens() throws {
        let readinessHero = waitForElement(AXID.activityHeroReadiness, timeout: 15)
        readinessHero.auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityTrainingReadinessDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Training Readiness detail should appear"
        )

        tapBackButton()
        ensureActivityRoot()

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionMuscleMap, maxSwipes: 8))
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.activityMuscleMapDetailLink, maxSwipes: 10),
            "Muscle Map detail link should be reachable"
        )
        waitForElement(AXID.activityMuscleMapDetailLink, timeout: 5).auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityMuscleMapDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Muscle Map detail should open"
        )

        tapBackButton()
        ensureActivityRoot()

        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.activitySectionWeeklyStats, maxSwipes: 12))
        waitForElement(AXID.activitySectionWeeklyStats, timeout: 5).auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityWeeklyStatsDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Weekly Stats detail should appear"
        )

        tapBackButton()
        ensureActivityRoot()

        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.activitySectionVolume, maxSwipes: 12))
        waitForElement(AXID.activitySectionVolume, timeout: 5).auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityTrainingVolumeDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Training Volume detail should open"
        )

        let exerciseTypeRow = app.descendants(matching: .any)[AXID.activityTrainingVolumeRow("manual-strength")].firstMatch
        XCTAssertTrue(exerciseTypeRow.waitForExistence(timeout: 8), "Seeded manual strength exercise type row should exist")
    }

    func testVisualAuditWeeklyStatsDetailDirect() throws {
        ensureActivityRoot()
        let rootScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        XCTAssertTrue(rootScroll.waitForExistence(timeout: 8))
        let weekly = app.buttons[AXID.activitySectionWeeklyStats].firstMatch
        for _ in 0..<14 where !weekly.isHittable { rootScroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(weekly.isHittable, "Weekly stats link should be visible")
        weekly.auditTap()
        let detail = app.descendants(matching: .any)[AXID.activityWeeklyStatsDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10))

        // The destination exists before its asynchronous comparison finishes loading.
        let summary = app.descendants(matching: .any)[AXID.activityWeeklyStatsSummaryGrid].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 15), "Weekly stats summary should finish loading")
        for id in ["volume", "duration", "calories", "activeDays", "sessions"] {
            let value = app.staticTexts["activity-weekly-stat-value-\(id)"].firstMatch
            XCTAssertTrue(value.waitForExistence(timeout: 10), "Current \(id) should exist")
            XCTAssertFalse(value.label.isEmpty, "Current \(id) should have a value")
        }
        VisualAudit.capture("Weekly stats detail")

        let detailScroll = app.scrollViews[AXID.activityWeeklyStatsDetailScreen].firstMatch
        let window = app.windows.firstMatch
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5) && window.exists,
                      "Weekly stats should own its scroll viewport")

        func visibleContent() -> CGRect {
            let base = detailScroll.frame.intersection(window.frame)
            var top = base.minY
            var bottom = base.maxY
            let navigation = app.navigationBars.firstMatch
            if navigation.exists && !navigation.frame.isEmpty && navigation.frame.intersects(base)
                && navigation.frame.midY < base.midY {
                top = min(bottom, max(top, navigation.frame.maxY))
            }
            let tabBar = app.tabBars.firstMatch
            if tabBar.exists && !tabBar.frame.isEmpty && tabBar.frame.intersects(base)
                && tabBar.frame.midY > base.midY {
                bottom = max(top, min(bottom, tabBar.frame.minY))
            }
            return CGRect(x: base.minX, y: top + 2,
                          width: max(0, base.width), height: max(0, bottom - top - 4))
        }

        func revealWhole(_ target: XCUIElement, value: XCUIElement) {
            for _ in 0..<12 {
                let viewport = visibleContent()
                let targetFrame = target.frame
                let valueFrame = value.frame
                if viewport.width > 0 && viewport.height > 0 && !targetFrame.isEmpty && !valueFrame.isEmpty
                    && viewport.contains(targetFrame) && viewport.contains(valueFrame)
                    && target.isHittable && value.isHittable { return }
                guard viewport.height > 44, !targetFrame.isEmpty else { break }
                let displacement: CGFloat
                if targetFrame.minY < viewport.minY {
                    displacement = min(max(viewport.minY - targetFrame.minY + 12, 44), viewport.height * 0.35)
                } else if targetFrame.maxY > viewport.maxY {
                    displacement = -min(max(targetFrame.maxY - viewport.maxY + 12, 44), viewport.height * 0.35)
                } else {
                    break
                }
                let origin = detailScroll.frame.origin
                let start = detailScroll.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: viewport.midX - origin.x, dy: viewport.midY - origin.y))
                let end = detailScroll.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: viewport.midX - origin.x,
                                         dy: viewport.midY + displacement - origin.y))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            let viewport = visibleContent()
            XCTAssertTrue(viewport.width > 0 && viewport.height > 0 && !target.frame.isEmpty
                          && !value.frame.isEmpty && viewport.contains(target.frame)
                          && viewport.contains(value.frame) && target.isHittable && value.isHittable,
                          "The whole comparison item and its value should be visible and hittable")
        }

        let caption = app.staticTexts["activity-weeklystats-previous-period"].firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 15), "Previous comparison should include its date range")
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let previousStart = try XCTUnwrap(calendar.date(byAdding: .day, value: -14, to: today))
        let previousEnd = try XCTUnwrap(calendar.date(byAdding: .day, value: -8, to: today))
        let supportedLocales = [Locale.current, Locale(identifier: "en_US"),
                                Locale(identifier: "ko_KR"), Locale(identifier: "ja_JP")]
        let expectedCaptions = supportedLocales.map { locale in
            let format = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
            return "\(previousStart.formatted(format)) – \(previousEnd.formatted(format))"
        }
        XCTAssertTrue(expectedCaptions.contains(caption.label),
                      "The previous caption should show the real previous start and end dates")
        XCTAssertEqual(app.staticTexts.matching(identifier: "activity-weeklystats-previous-period").count, 1)
        revealWhole(caption, value: caption)
        VisualAudit.capture("A05 previous comparison date")

        for id in ["volume", "duration", "calories", "sessions"] {
            let row = app.descendants(matching: .any)["activity-weeklystats-previous-\(id)"].firstMatch
            let value = app.staticTexts["activity-weeklystats-previous-value-\(id)"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10), "Previous \(id) row should exist")
            XCTAssertTrue(value.waitForExistence(timeout: 10), "Previous \(id) value should exist")
            XCTAssertFalse(value.label.isEmpty, "Previous \(id) should have a value")
            revealWhole(row, value: value)
            VisualAudit.capture("A05 previous comparison \(id) row")
        }

        tapBackButton()
        XCTAssertTrue(detail.waitForNonExistence(timeout: 8), "Weekly stats detail should dismiss")
        ensureActivityRoot()
    }

    func testActivitySecondaryDetailRoutesOpenExpectedScreens() throws {
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.activitySectionPR, maxSwipes: 12))
        waitForElement(AXID.activitySectionPR, timeout: 5).auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityPersonalRecordsDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Personal Records should open"
        )

        tapBackButton()
        ensureActivityRoot()

        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.activitySectionConsistency, maxSwipes: 12))
        waitForElement(AXID.activitySectionConsistency, timeout: 5).auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityConsistencyDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Consistency detail should open"
        )
    }

    func testActivityExerciseMixRouteOpensExpectedScreen() throws {
        try assertExerciseMixDetail(maxText: false)
    }

    func testActivityExerciseMixAtMaximumAccessibilityTextSize() throws {
        try assertExerciseMixDetail(maxText: true)
    }

    private func assertExerciseMixDetail(maxText: Bool) throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        if maxText {
            configuration.additionalArguments.append(contentsOf: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ])
        }
        launchApp(with: configuration)
        openActivityDetail(sectionIdentifier: AXID.activitySectionExerciseMix,
                           destinationIdentifier: AXID.activityExerciseMixDetailScreen, maxSwipes: maxText ? 32 : 12)
        let scroll = app.scrollViews[AXID.activityExerciseMixDetailScreen].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))

        func viewport() -> CGRect {
            let base = scroll.frame.intersection(app.windows.firstMatch.frame)
            var top = base.minY
            var bottom = base.maxY
            let navigation = app.navigationBars.firstMatch
            if navigation.exists && !navigation.frame.isEmpty && navigation.frame.intersects(base)
                && navigation.frame.midY < base.midY {
                top = min(bottom, max(top, navigation.frame.maxY))
            }
            let tabBar = app.tabBars.firstMatch
            if tabBar.exists && !tabBar.frame.isEmpty && tabBar.frame.intersects(base)
                && tabBar.frame.midY > base.midY {
                bottom = max(top, min(bottom, tabBar.frame.minY))
            }
            return CGRect(x: base.minX, y: top + 2, width: max(0, base.width),
                          height: max(0, bottom - top - 4))
        }

        func visible(_ id: String) -> XCUIElement {
            let element = app.descendants(matching: .any)[id].firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing \(id)")
            for _ in 0..<24 {
                let bounds = viewport()
                if !element.frame.isEmpty && bounds.contains(element.frame) { break }
                if element.exists && element.frame.midY < bounds.midY {
                    scroll.swipeDown(velocity: .slow)
                } else {
                    scroll.swipeUp(velocity: .slow)
                }
            }
            XCTAssertFalse(element.frame.isEmpty, "Empty frame: \(id)")
            XCTAssertTrue(viewport().contains(element.frame), "Not fully visible: \(id)")
            return element
        }

        let total = visible("activity-exercise-mix-total")
        let parsedTotal = Int(total.label.replacingOccurrences(of: ",", with: ""))
        XCTAssertNotNil(parsedTotal, "The total must be an actual formatted integer: \(total.label)")
        XCTAssertGreaterThan(parsedTotal ?? 0, 0, "The seeded route must contain workout records")
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let firstDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -27, to: today))
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
        let dateRange = visible("activity-exercise-mix-date-range").label
        XCTAssertTrue(dateRange.contains(dateFormatter.string(from: firstDay)), dateRange)
        XCTAssertTrue(dateRange.contains(dateFormatter.string(from: today)), dateRange)
        var categoryTotal = 0
        for category in ["strength", "cardio", "other"] {
            let id = "activity-exercise-mix-category-count-\(category)"
            let candidate = app.descendants(matching: .any)[id].firstMatch
            if category == "other" && !candidate.exists { continue }
            let value = visible(id).label.replacingOccurrences(of: ",", with: "")
            let count = try XCTUnwrap(Int(value), "Invalid category value: \(value)")
            XCTAssertGreaterThanOrEqual(count, 0)
            categoryTotal += count
        }
        XCTAssertEqual(categoryTotal, parsedTotal, "Category counts must sum to the displayed total")
        VisualAudit.capture("A12 exercise mix summary \(maxText ? "MAX" : "normal")")
        _ = visible("activity-exercise-mix-weekly-heading")
        let week = visible("activity-exercise-mix-weekly-total")
        XCTAssertNotNil(Int(week.label.replacingOccurrences(of: ",", with: "")))
        VisualAudit.capture("A12 exercise mix weekly \(maxText ? "MAX" : "normal")")
        _ = visible("activity-exercise-mix-muscle-heading")
        let muscleSets = app.descendants(matching: .any)["activity-exercise-mix-muscle-sets"].firstMatch
        let muscleLeaf = visible(muscleSets.exists ? "activity-exercise-mix-muscle-sets" : "activity-exercise-mix-muscle-empty")
        XCTAssertFalse(muscleLeaf.label.isEmpty)
        VisualAudit.capture("A12 exercise mix muscles \(maxText ? "MAX" : "normal")")
        _ = visible("activity-exercise-mix-cardio-heading")
        let cardioCount = app.descendants(matching: .any)["activity-exercise-mix-cardio-count"].firstMatch
        let cardioLeaf = visible(cardioCount.exists ? "activity-exercise-mix-cardio-count" : "activity-exercise-mix-cardio-empty")
        XCTAssertFalse(cardioLeaf.label.isEmpty)
        VisualAudit.capture("A12 exercise mix cardio \(maxText ? "MAX" : "normal")")

        let chart = visible("activity-exercise-mix-donut-chart")
        let center = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.withOffset(CGVector(dx: 65, dy: 0)).tap()
        let prefix = "activity-exercise-mix-selected-name-"
        let selection = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(selection.waitForExistence(timeout: 10), "A donut sector should select an exercise")
        let selectedName = visible(selection.identifier)
        XCTAssertFalse(selectedName.label.isEmpty)
        let selectedKey = String(selectedName.identifier.dropFirst(prefix.count))
        XCTAssertFalse(selectedKey.isEmpty)
        let selectedCount = visible("activity-exercise-mix-selected-count-\(selectedKey)")
        XCTAssertTrue(selectedCount.label.hasSuffix("x"), selectedCount.label)
        let count = Int(String(selectedCount.label.dropLast()).replacingOccurrences(of: ",", with: ""))
        XCTAssertGreaterThan(count ?? 0, 0, "The selected exercise must have a real positive frequency")
        let nameValue = selectedName.label
        let countValue = selectedCount.label
        VisualAudit.capture("A12 exercise mix selected donut \(maxText ? "MAX" : "normal")")
        let exercise = visible("activity-exercise-mix-frequency-name-\(selectedKey)")
        XCTAssertEqual(exercise.label, nameValue)
        let frequency = visible("activity-exercise-mix-frequency-count-\(selectedKey)")
        XCTAssertEqual(frequency.label, countValue)
        VisualAudit.capture("A12 exercise mix frequency \(maxText ? "MAX" : "normal")")
        tapBackButton()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityRootScroll].firstMatch.waitForExistence(timeout: 10),
                      "Back should return to Activity")
        XCTAssertTrue(calendar.isDateInToday(today), "The date range assertions require one local day")
    }

    func testActivityRiskAndReportRoutesOpen() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-design-map-activity-routes")
        launchApp(with: configuration)
        let activityScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        let riskLink = app.descendants(matching: .any)["activity-injuryrisk-detail-link"].firstMatch
        XCTAssertTrue(activityScroll.waitForExistence(timeout: 5))
        for _ in 0..<24 where !riskLink.isHittable { activityScroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(riskLink.isHittable)
        waitForElement("activity-injuryrisk-detail-link", timeout: 5).auditTap()
        XCTAssertTrue(app.descendants(matching: .any)["activity-injury-risk-detail-screen"].firstMatch
            .waitForExistence(timeout: 10))

        // This score and two factors are the existing DEBUG route fixture, not production risk inputs.
        let score = app.staticTexts["activity-injury-risk-score"].firstMatch
        XCTAssertTrue(score.waitForExistence(timeout: 10))
        XCTAssertEqual(score.label, "42")
        let rows = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "activity-injury-risk-factor-"
        ))
        XCTAssertEqual(rows.count, 2, "The route fixture supplies exactly two risk factors")
        for (type, value) in [("muscleFatigue", "+24"), ("sleepDeficit", "+18")] {
            XCTAssertTrue(app.descendants(matching: .any)["activity-injury-risk-factor-\(type)"]
                .firstMatch.waitForExistence(timeout: 5))
            let contribution = app.staticTexts["activity-injury-risk-contribution-\(type)"].firstMatch
            XCTAssertEqual(contribution.label, value)
        }
        XCTAssertTrue(app.descendants(matching: .any)["activity-injury-risk-recommendations"]
            .firstMatch.waitForExistence(timeout: 5))
        addScreenshotAttachment(named: "Injury Risk loaded DEBUG route assessment")
        VisualAudit.capture("Injury Risk loaded DEBUG route assessment")

        tapBackButton()
        ensureActivityRoot()

        let reportLink = app.descendants(matching: .any)["activity-weeklyreport-detail-link"].firstMatch
        for _ in 0..<24 where !reportLink.isHittable { activityScroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(reportLink.isHittable)
        waitForElement("activity-weeklyreport-detail-link", timeout: 5).auditTap()
        let report = app.descendants(matching: .any)["activity-weekly-report-detail-screen"].firstMatch
        XCTAssertTrue(report.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["activity-weekly-report-volume"].firstMatch.label, "2.4k")
        XCTAssertEqual(app.staticTexts["activity-weekly-report-sessions"].firstMatch.label, "3")
        XCTAssertEqual(app.staticTexts["activity-weekly-report-active-days"].firstMatch.label, "3")
        XCTAssertEqual(app.staticTexts["activity-weekly-report-duration"].firstMatch.label, "5400 min")
        XCTAssertEqual(app.staticTexts["activity-weekly-report-intensity"].firstMatch.label, "72%")
        XCTAssertEqual(app.staticTexts["activity-weekly-report-change"].firstMatch.label, "+12%")
        XCTAssertFalse(app.staticTexts["activity-weekly-report-date"].firstMatch.label.isEmpty)
        addScreenshotAttachment(named: "Activity Weekly Report A09 loaded hero")
        VisualAudit.capture("Activity Weekly Report A09 loaded hero")

        let summary = app.staticTexts["activity-weekly-report-summary"].firstMatch
        let highlight = app.staticTexts["activity-weekly-report-highlight"].firstMatch
        XCTAssertTrue(summary.exists)
        XCTAssertFalse(summary.label.isEmpty)
        XCTAssertTrue(highlight.exists)
        XCTAssertFalse(highlight.label.isEmpty)
        let muscleValues = app.staticTexts.matching(identifier: "activity-weekly-report-muscle-volume")
        XCTAssertEqual(muscleValues.count, 2)
        XCTAssertEqual(Set((0..<muscleValues.count).map { muscleValues.element(boundBy: $0).label }),
                       Set(["1.1k", "1.3k"]))
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-weekly-report-muscle-volume", maxSwipes: 8))
        addScreenshotAttachment(named: "Activity Weekly Report A09 highlights and muscle breakdown")
        VisualAudit.capture("Activity Weekly Report A09 highlights and muscle breakdown")
        tapBackButton()
        ensureActivityRoot()
    }

    func testWeeklyReportAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "--ui-design-map-activity-routes",
            "--ui-test-style", "dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)

        let window = app.windows.firstMatch
        let activityScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        let reportLink = app.buttons["activity-weeklyreport-detail-link"].firstMatch
        XCTAssertTrue(activityScroll.waitForExistence(timeout: 5))
        for _ in 0..<32 {
            let viewport = activityScroll.frame.intersection(window.frame)
            if reportLink.exists && reportLink.isHittable && viewport.contains(reportLink.frame) { break }
            if reportLink.exists && reportLink.frame.midY < viewport.midY {
                activityScroll.swipeDown(velocity: .slow)
            } else {
                activityScroll.swipeUp(velocity: .slow)
            }
        }
        XCTAssertTrue(reportLink.exists && reportLink.isHittable,
                      "The report link should be reachable in the AX Activity root")
        reportLink.auditTap()

        let reportScroll = app.scrollViews["activity-weekly-report-detail-screen"].firstMatch
        XCTAssertTrue(reportScroll.waitForExistence(timeout: 10))

        func revealInReport(_ element: XCUIElement, name: String) {
            for _ in 0..<12 {
                let viewport = reportScroll.frame.intersection(window.frame)
                if element.exists && element.isHittable && viewport.contains(element.frame) { return }
                if element.exists && element.frame.midY < viewport.midY {
                    reportScroll.swipeDown(velocity: .slow)
                } else {
                    reportScroll.swipeUp(velocity: .slow)
                }
            }
            let viewport = reportScroll.frame.intersection(window.frame)
            XCTAssertTrue(element.exists && element.isHittable && viewport.contains(element.frame),
                          "\(name) should fit within the A09 report scroll viewport")
        }

        // These exact numbers are the existing DEBUG report fixture, not personal workouts.
        let volume = app.staticTexts["activity-weekly-report-volume"].firstMatch
        let sessions = app.staticTexts["activity-weekly-report-sessions"].firstMatch
        let activeDays = app.staticTexts["activity-weekly-report-active-days"].firstMatch
        let duration = app.staticTexts["activity-weekly-report-duration"].firstMatch
        let intensity = app.staticTexts["activity-weekly-report-intensity"].firstMatch
        let change = app.staticTexts["activity-weekly-report-change"].firstMatch
        XCTAssertTrue(volume.waitForExistence(timeout: 10))
        XCTAssertEqual(volume.label, "2.4k")
        XCTAssertEqual(sessions.label, "3")
        XCTAssertEqual(activeDays.label, "3")
        XCTAssertEqual(duration.label, "5400 min")
        XCTAssertEqual(intensity.label, "72%")
        XCTAssertEqual(change.label, "+12%")
        XCTAssertFalse(app.staticTexts["activity-weekly-report-date"].firstMatch.label.isEmpty)
        revealInReport(volume, name: "Report volume")
        addScreenshotAttachment(named: "A09 dark maximum AX report hero")
        VisualAudit.capture("A09 dark maximum AX report hero")
        revealInReport(duration, name: "Report duration in minutes")
        addScreenshotAttachment(named: "A09 dark maximum AX hero duration")
        VisualAudit.capture("A09 dark maximum AX hero duration")

        let summary = app.staticTexts["activity-weekly-report-summary"].firstMatch
        let highlight = app.staticTexts["activity-weekly-report-highlight"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(highlight.waitForExistence(timeout: 5))
        XCTAssertFalse(summary.label.isEmpty)
        XCTAssertFalse(highlight.label.isEmpty)
        revealInReport(summary, name: "Report summary")
        addScreenshotAttachment(named: "A09 dark maximum AX summary")
        VisualAudit.capture("A09 dark maximum AX summary")
        revealInReport(highlight, name: "Report highlight")
        addScreenshotAttachment(named: "A09 dark maximum AX highlight")
        VisualAudit.capture("A09 dark maximum AX highlight")

        let muscles = app.staticTexts.matching(identifier: "activity-weekly-report-muscle-volume")
        XCTAssertEqual(muscles.count, 2)
        XCTAssertEqual(muscles.element(boundBy: 0).label, "1.1k")
        XCTAssertEqual(muscles.element(boundBy: 1).label, "1.3k")
        revealInReport(muscles.element(boundBy: 1), name: "Second muscle volume")
        addScreenshotAttachment(named: "A09 dark maximum AX relative muscle bars")
        VisualAudit.capture("A09 dark maximum AX relative muscle bars")

        tapBackButton()
        ensureActivityRoot()
    }

    func testInjuryRiskAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "--ui-design-map-activity-routes",
            "--ui-test-style", "dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)

        let activityScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        let riskLink = app.descendants(matching: .any)["activity-injuryrisk-detail-link"].firstMatch
        XCTAssertTrue(activityScroll.waitForExistence(timeout: 5))
        for _ in 0..<24 where !riskLink.isHittable { activityScroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(riskLink.isHittable)
        riskLink.auditTap()

        let riskScroll = app.scrollViews["activity-injury-risk-detail-screen"].firstMatch
        XCTAssertTrue(riskScroll.waitForExistence(timeout: 10))
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)

        func revealInRiskScroll(_ element: XCUIElement, name: String) {
            for _ in 0..<10 {
                let viewport = riskScroll.frame.intersection(window.frame)
                if element.exists && element.isHittable && viewport.contains(element.frame) { return }
                if element.exists && element.frame.midY < viewport.midY {
                    riskScroll.swipeDown(velocity: .slow)
                } else {
                    riskScroll.swipeUp(velocity: .slow)
                }
            }
            let viewport = riskScroll.frame.intersection(window.frame)
            XCTAssertTrue(element.exists && element.isHittable && viewport.contains(element.frame),
                          "\(name) should fit within the Injury Risk detail scroll viewport")
        }

        // These values belong only to the existing DEBUG route assessment.
        let score = app.staticTexts["activity-injury-risk-score"].firstMatch
        XCTAssertTrue(score.waitForExistence(timeout: 10))
        XCTAssertEqual(score.label, "42")
        revealInRiskScroll(score, name: "Risk score")
        XCTAssertTrue(app.descendants(matching: .any)["activity-injury-risk-level"].firstMatch.exists)
        addScreenshotAttachment(named: "Injury Risk A08 dark maximum AX hero")
        VisualAudit.capture("Injury Risk A08 dark maximum AX hero")

        let factors = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "activity-injury-risk-factor-"
        ))
        XCTAssertEqual(factors.count, 2)
        for (type, value) in [("muscleFatigue", "+24"), ("sleepDeficit", "+18")] {
            let row = app.descendants(matching: .any)["activity-injury-risk-factor-\(type)"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            revealInRiskScroll(row, name: "\(type) factor")
            XCTAssertEqual(app.staticTexts["activity-injury-risk-contribution-\(type)"].firstMatch.label, value)
        }
        addScreenshotAttachment(named: "Injury Risk A08 dark maximum AX factors")
        VisualAudit.capture("Injury Risk A08 dark maximum AX factors")

        let recommendations = app.descendants(matching: .any)["activity-injury-risk-recommendations"].firstMatch
        XCTAssertTrue(recommendations.waitForExistence(timeout: 5))
        let lastRecommendation = app.staticTexts["activity-injury-risk-recommendation-2"].firstMatch
        XCTAssertTrue(lastRecommendation.waitForExistence(timeout: 5))
        revealInRiskScroll(lastRecommendation, name: "Last recommendation")
        XCTAssertFalse(lastRecommendation.label.isEmpty)
        addScreenshotAttachment(named: "Injury Risk A08 dark maximum AX last recommendation")
        VisualAudit.capture("Injury Risk A08 dark maximum AX last recommendation")

        tapBackButton()
        ensureActivityRoot()
    }

    func testVisualAuditPersonalRecordsExplanation() throws {
        openActivityInfo(button: "activity-pr-info", sheet: "activity-personal-records-info-sheet")
    }

    func testVisualAuditConsistencyExplanation() throws {
        openActivityInfo(button: "activity-consistency-info", sheet: "activity-consistency-info-sheet")
    }

    func testVisualAuditExerciseMixExplanation() throws {
        openActivityInfo(button: "activity-exercise-mix-info", sheet: "activity-exercise-mix-info-sheet")
    }

    func testVisualAuditRecoveryAlgorithmExplanation() throws {
        openActivityInfo(button: "activity-muscle-map-algorithm-info", sheet: "activity-fatigue-algorithm-sheet")
    }

    func testVisualAuditVolumeAlgorithmExplanation() throws {
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-muscle-map-algorithm-info", maxSwipes: 10))
        let mode = app.segmentedControls["activity-muscle-map-mode"].firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        let volume = mode.buttons.element(boundBy: 1)
        XCTAssertTrue(volume.waitForExistence(timeout: 5))
        volume.auditTap()
        let info = app.buttons["activity-muscle-map-algorithm-info"].firstMatch
        let rootScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        for _ in 0..<30 where !info.isHittable { rootScroll.swipeDown(velocity: .slow) }
        XCTAssertTrue(info.isHittable, "Volume calculation info should be visible")
        info.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)["activity-volume-algorithm-sheet"].firstMatch
            .waitForExistence(timeout: 10))
        VisualAudit.capture("Volume algorithm explanation")
    }

    func testVisualAuditMuscleDetailPopover() throws {
        let muscle = app.buttons["musclemap-body-front-chest"].firstMatch
        let activityScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        XCTAssertTrue(activityScroll.waitForExistence(timeout: 5))
        for _ in 0..<24 where !muscle.isHittable { activityScroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(muscle.isHittable)
        muscle.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)["activity-muscle-detail-popover-sheet"].firstMatch
            .waitForExistence(timeout: 10))
        VisualAudit.capture("Muscle detail popover")
    }

    func testVisualAuditMuscleFatigueExplanation() throws {
        let muscle = app.buttons["musclemap-body-front-chest"].firstMatch
        let activityScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        XCTAssertTrue(activityScroll.waitForExistence(timeout: 5))
        for _ in 0..<24 where !muscle.isHittable { activityScroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(muscle.isHittable)
        muscle.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)["activity-muscle-detail-popover-sheet"].firstMatch
            .waitForExistence(timeout: 10))
        let calculation = app.buttons["activity-muscle-detail-calculation"].firstMatch
        XCTAssertTrue(calculation.waitForExistence(timeout: 8))
        calculation.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)["activity-fatigue-info-sheet"].firstMatch
            .waitForExistence(timeout: 10))
        VisualAudit.capture("Muscle fatigue explanation")
    }

    func testVisualAuditRecommendationEquipmentInfo() throws {
        let target = app.buttons["activity-recommendation-equipment-info"].firstMatch
        let rootScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        XCTAssertTrue(rootScroll.waitForExistence(timeout: 8))
        for _ in 0..<30 where !target.isHittable { rootScroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(target.isHittable)
        target.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)["activity-recommendation-equipment-sheet"].firstMatch
            .waitForExistence(timeout: 10))
        VisualAudit.capture("Recommendation equipment sheet")
    }

    private func openActivityInfo(button: String, sheet: String) {
        let target = app.buttons[button].firstMatch
        let rootScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        XCTAssertTrue(rootScroll.waitForExistence(timeout: 8))
        for _ in 0..<30 where !target.isHittable {
            rootScroll.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(target.isHittable, "\(button) should be reachable")
        target.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[sheet].firstMatch.waitForExistence(timeout: 10),
                      "\(sheet) should open")
        VisualAudit.capture(sheet)
    }

    func testVisualAuditPersonalRecordShareSheet() throws {
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionPR, maxSwipes: 10))
        waitForElement(AXID.activitySectionPR, timeout: 5).auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityPersonalRecordsDetailScreen].firstMatch
            .waitForExistence(timeout: 10))

        let shareID = "activity-personal-records-share-button"
        let share = app.buttons[shareID].firstMatch
        let detailScroll = app.scrollViews[AXID.activityPersonalRecordsDetailScreen].firstMatch
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5))
        for _ in 0..<8 where !share.isHittable { detailScroll.swipeDown(velocity: .slow) }
        for _ in 0..<12 where !share.isHittable { detailScroll.swipeUp(velocity: .slow) }
        XCTAssertTrue(share.isHittable, "Personal record share button should be visible")
        share.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)["share-image-sheet"].firstMatch
            .waitForExistence(timeout: 10))
        VisualAudit.capture("Personal record image share sheet")
    }

    func testExerciseTypeDetailShowsTrendSurface() throws {
        try verifyManualExerciseTypeDetailAndCapture()
    }

    func testExerciseTypeDetailAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "--ui-test-style", "dark"
        ]
        launchApp(with: configuration)
        try verifyManualExerciseTypeDetailAndCapture(maximumAccessibilitySize: true)
    }

    private func verifyManualExerciseTypeDetailAndCapture(maximumAccessibilitySize: Bool = false) throws {
        openTrainingVolumeDetailSurface(maximumAccessibilitySize: maximumAccessibilitySize)

        // On the AX route, scope later reveals to the pushed detail scrolls. Activity's
        // root scroll can remain in the accessibility tree behind a navigation push.
        func revealInDetailScroll(_ scrollID: String, targetID: String, maxSwipes: Int = 12) -> Bool {
            let scroll = app.scrollViews[scrollID].firstMatch
            guard scroll.waitForExistence(timeout: 5) else { return false }
            let target = app.descendants(matching: .any)[targetID].firstMatch
            let window = app.windows.firstMatch
            for _ in 0..<maxSwipes {
                let viewport = scroll.frame.intersection(window.frame)
                if target.exists && target.isHittable
                    && viewport.contains(CGPoint(x: target.frame.midX, y: target.frame.midY)) {
                    return true
                }
                if target.exists && target.frame.midY < viewport.midY {
                    scroll.swipeDown(velocity: .slow)
                } else {
                    scroll.swipeUp(velocity: .slow)
                }
            }
            let viewport = scroll.frame.intersection(window.frame)
            return target.exists && target.isHittable
                && viewport.contains(CGPoint(x: target.frame.midX, y: target.frame.midY))
        }

        if maximumAccessibilitySize {
            XCTAssertTrue(app.descendants(matching: .any)[AXID.activityTrainingVolumeTypeList]
                .firstMatch.waitForExistence(timeout: 10),
                "Exercise type list should exist in Training Volume detail")
            XCTAssertTrue(
                revealInDetailScroll(
                    AXID.activityTrainingVolumeDetailScreen,
                    targetID: AXID.activityTrainingVolumeRow(Fixture.manualStrengthTypeKey)
                ),
                "Manual strength row should be reachable in Training Volume detail"
            )
        } else {
            XCTAssertTrue(
                app.scrollToElementIfNeeded(AXID.activityTrainingVolumeTypeList, maxSwipes: 10),
                "Exercise type list should be reachable in Training Volume detail"
            )
            XCTAssertTrue(
                app.scrollToHittableElementIfNeeded(
                    AXID.activityTrainingVolumeRow(Fixture.manualStrengthTypeKey), maxSwipes: 10
                ),
                "Manual strength row should be reachable in Training Volume detail"
            )
        }
        let row = app.descendants(matching: .any)[AXID.activityTrainingVolumeRow(Fixture.manualStrengthTypeKey)].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Manual strength row should exist in Training Volume detail")
        row.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityExerciseTypeDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Exercise type detail should open from the Training Volume detail list"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityExerciseTypePeriodPicker].firstMatch.waitForExistence(timeout: 15),
            "Exercise type detail should expose the period picker"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityExerciseTypeTrendChart].firstMatch.waitForExistence(timeout: 15),
            "Exercise type detail should render the trend chart"
        )

        let primaryValue = app.staticTexts["activity-exercise-type-primary-value"].firstMatch
        let comparisonVolume = app.staticTexts["activity-exercise-type-comparison-current-volume"].firstMatch
        XCTAssertTrue(primaryValue.waitForExistence(timeout: 15), "Seeded manual strength hero must finish loading")
        XCTAssertEqual(primaryValue.label, "6.4t", "The actual completed-set weight × reps total should lead")
        XCTAssertTrue(comparisonVolume.waitForExistence(timeout: 5))
        XCTAssertEqual(comparisonVolume.label, primaryValue.label,
                       "Hero and comparison must use the same selected type total")
        XCTAssertFalse(app.descendants(matching: .any)[AXID.activityExerciseTypeRecentSessions].firstMatch.exists,
                       "A manual type must not invent HealthKit workout history")
        VisualAudit.capture("Exercise type manual strength Week loaded")
        XCTAssertTrue(
            maximumAccessibilitySize
                ? revealInDetailScroll(
                    AXID.activityExerciseTypeDetailScreen,
                    targetID: "activity-exercise-type-comparison-row-volume"
                )
                : app.scrollToHittableElementIfNeeded("activity-exercise-type-comparison-row-volume", maxSwipes: 8),
            "The real weighted-volume comparison should be reachable"
        )
        VisualAudit.capture("Exercise type manual strength Week comparison")

        XCTAssertTrue(
            maximumAccessibilitySize
                ? revealInDetailScroll(
                    AXID.activityExerciseTypeDetailScreen,
                    targetID: AXID.activityExerciseTypePeriodPicker
                )
                : app.scrollToHittableElementIfNeeded(
                    AXID.activityExerciseTypePeriodPicker, maxSwipes: 8, direction: .down
                ),
            "The exercise type period control should remain reachable after comparison"
        )
        tapSegment(in: AXID.activityExerciseTypePeriodPicker, index: 1, timeout: 10)

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityExerciseTypeTrendChart].firstMatch.waitForExistence(timeout: 15),
            "Exercise type detail should keep the trend chart visible after period switching"
        )
        XCTAssertEqual(primaryValue.label, "6.4t",
                       "The seeded three manual sessions remain in the Month window")
        VisualAudit.capture("Exercise type manual strength Month loaded")
    }

    func testPersonalRecordsDetailShowsTimelineRewardsAndHistory() throws {
        if VisualAudit.isEnabled {
            var configuration = launchConfiguration
            configuration.additionalArguments += [
                "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                "--ui-test-style", "dark",
                "--ui-visual-personal-records-recent-fixture"
            ]
            launchApp(with: configuration)
            XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        }
        openActivityDetail(
            sectionIdentifier: AXID.activitySectionPR,
            destinationIdentifier: AXID.activityPersonalRecordsDetailScreen,
            maxSwipes: 24
        )

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityPersonalRecordsPeriodPicker].firstMatch.waitForExistence(timeout: 15),
            "Personal Records detail should expose the period picker"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityPersonalRecordsTimelineChart].firstMatch.waitForExistence(timeout: 15),
            "Personal Records detail should render the timeline chart"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityPersonalRecordsRewardProgress].firstMatch.waitForExistence(timeout: 15),
            "Personal Records detail should show reward progress"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityPersonalRecordsAchievementHistory].firstMatch.waitForExistence(timeout: 15),
            "Personal Records detail should show the achievement history"
        )
        if VisualAudit.isEnabled {
            let scroll = app.scrollViews[AXID.activityPersonalRecordsDetailScreen].firstMatch
            XCTAssertTrue(scroll.waitForExistence(timeout: 5), "Personal Records should own its scroll viewport")

            func viewport() -> CGRect {
                let window = app.windows.firstMatch.frame
                var visible = scroll.frame.intersection(window).insetBy(dx: 8, dy: 8)
                let nav = app.navigationBars.firstMatch
                if nav.exists && nav.frame.intersects(visible) && nav.frame.midY < visible.midY {
                    let top = min(visible.maxY, nav.frame.maxY)
                    visible = CGRect(x: visible.minX, y: top, width: visible.width, height: visible.maxY - top)
                }
                let tab = app.tabBars.firstMatch
                if tab.exists && tab.isHittable && tab.frame.intersects(visible) && tab.frame.midY > visible.midY {
                    visible.size.height = max(0, tab.frame.minY - visible.minY)
                }
                return visible
            }

            func reveal(_ element: XCUIElement, named name: String) {
                XCTAssertTrue(element.waitForExistence(timeout: 10), "\(name) should exist")
                for _ in 0..<20 {
                    let visible = viewport()
                    if visible.contains(element.frame) && element.isHittable { return }
                    if element.frame.midY < visible.midY { scroll.swipeDown(velocity: .slow) }
                    else { scroll.swipeUp(velocity: .slow) }
                }
                XCTAssertTrue(viewport().contains(element.frame) && element.isHittable,
                              "The complete \(name) should be reachable in the detail viewport")
            }

            func captureLeaf(_ element: XCUIElement, named name: String) {
                reveal(element, named: name)
                VisualAudit.capture("Personal Records maximum AX \(name)")
                addScreenshotAttachment(named: "Personal Records maximum AX \(name)")
            }

            let heading = app.staticTexts["activity-personal-records-best-heading"].firstMatch
            reveal(heading, named: "current best heading")
            XCTAssertEqual(heading.label, "Current Best")
            let maximumTraits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
            let headingLine = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: maximumTraits).lineHeight
            XCTAssertLessThanOrEqual(heading.frame.height, headingLine * 2 + 1,
                                     "Current Best should use at most two headline lines")
            let newBadge = app.staticTexts["activity-personal-records-best-new"].firstMatch
            reveal(newBadge, named: "new record badge")
            XCTAssertEqual(newBadge.label, "NEW")
            let badgeLine = UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: maximumTraits).lineHeight
            XCTAssertLessThanOrEqual(newBadge.frame.height, badgeLine + 2 * 4 + 1,
                                     "NEW should remain on one readable line")
            VisualAudit.capture("Personal Records maximum AX best heading and new badge")
            addScreenshotAttachment(named: "Personal Records maximum AX best heading and new badge")

            let best = app.staticTexts["activity-personal-records-best-value"].firstMatch
            XCTAssertTrue(best.waitForExistence(timeout: 10))
            XCTAssertFalse(best.label.isEmpty)
            captureLeaf(best, named: "best value")
            let share = app.buttons["activity-personal-records-share-button"].firstMatch
            reveal(share, named: "Share")
            XCTAssertGreaterThanOrEqual(share.frame.width, 44, "Share must have a 44-point target")
            XCTAssertGreaterThanOrEqual(share.frame.height, 44, "Share must have a 44-point target")
            VisualAudit.capture("Personal Records maximum AX Share")
            addScreenshotAttachment(named: "Personal Records maximum AX Share")

            let periodMenu = app.buttons[AXID.activityPersonalRecordsPeriodPicker].firstMatch
            reveal(periodMenu, named: "period menu")
            XCTAssertGreaterThanOrEqual(periodMenu.frame.height, 44)
            XCTAssertGreaterThanOrEqual(periodMenu.frame.width, 44)
            let range = app.staticTexts["activity-personal-records-chart-range"].firstMatch
            XCTAssertTrue(range.waitForExistence(timeout: 10))
            let defaultRange = range.label
            let originalBest = best.label
            XCTAssertFalse(defaultRange.isEmpty)
            XCTAssertEqual(periodMenu.value as? String, "6M")
            VisualAudit.capture("Personal Records maximum AX period menu")
            addScreenshotAttachment(named: "Personal Records maximum AX period menu")
            var previousRange = defaultRange
            for period in ["D", "W", "M", "Y", "6M"] {
                reveal(periodMenu, named: "period menu")
                periodMenu.tap()
                let option = app.buttons["activity-personal-records-period-\(period)"].firstMatch
                XCTAssertTrue(option.waitForExistence(timeout: 5), "\(period) menu choice should exist")
                option.tap()
                let changed = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "label != %@", previousRange), object: range
                )
                XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed,
                               "The selected period should update its actual date range")
                XCTAssertEqual(periodMenu.value as? String, period)
                XCTAssertEqual(best.label, originalBest, "Period selection must preserve the all-time best")
                previousRange = range.label
            }
            XCTAssertEqual(range.label, defaultRange, "Returning to 6M restores its original date range")
            captureLeaf(app.descendants(matching: .any)["personal-records-timeline-latest-value"].firstMatch,
                        named: "timeline latest value")
            captureLeaf(app.descendants(matching: .any)["activity-personal-records-timeline-plot"].firstMatch,
                        named: "timeline plot and axes")
            captureLeaf(app.staticTexts["activity-personal-records-reward-level"].firstMatch,
                        named: "reward level")
            captureLeaf(app.staticTexts["activity-personal-records-reward-points"].firstMatch,
                        named: "reward points")
            reveal(app.descendants(matching: .any)["activity-personal-records-level-progress"].firstMatch,
                   named: "level progress")
            let badgesScroll = app.scrollViews["activity-personal-records-badges-scroll"].firstMatch
            reveal(badgesScroll, named: "badge trophy viewport")
            let badgeName = app.staticTexts["activity-personal-records-badge-name-badge-10-prs"].firstMatch
            XCTAssertTrue(badgeName.waitForExistence(timeout: 10), "PR Collector badge should exist")
            for _ in 0..<8 {
                let visible = badgesScroll.frame.intersection(viewport())
                let target = badgeName.frame
                if !visible.isEmpty && !target.isEmpty && visible.contains(target) { break }
                guard visible.width > 44, !target.isEmpty else { break }
                let displacement: CGFloat
                if target.minX < visible.minX {
                    displacement = min(max(visible.minX - target.minX + 12, 1), visible.width * 0.35)
                } else if target.maxX > visible.maxX {
                    displacement = -min(max(target.maxX - visible.maxX + 12, 1), visible.width * 0.35)
                } else {
                    break
                }
                let origin = badgesScroll.frame.origin
                let start = badgesScroll.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: visible.midX - origin.x, dy: visible.midY - origin.y))
                let end = badgesScroll.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: visible.midX + displacement - origin.x,
                                         dy: visible.midY - origin.y))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            let badgeViewport = badgesScroll.frame.intersection(viewport())
            XCTAssertEqual(badgeName.label, "PR Collector")
            XCTAssertFalse(badgeName.frame.isEmpty)
            // Retain complete containment with a bounded subpoint tolerance.
            // The prior rounded AX dump does not establish the exact edge mismatch.
            XCTAssertTrue(!badgeViewport.isEmpty && badgeViewport.insetBy(dx: -0.5, dy: -0.5).contains(badgeName.frame),
                          "The complete actual badge name must fit the visible trophy viewport (0.5pt edge tolerance)")
            VisualAudit.capture("Personal Records maximum AX badge PR Collector")
            addScreenshotAttachment(named: "Personal Records maximum AX badge PR Collector")

            let titlePrefix = "activity-personal-records-achievement-title-"
            let firstTitle = app.staticTexts.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", titlePrefix)
            ).firstMatch
            let empty = app.staticTexts["activity-personal-records-history-empty"].firstMatch
            // Revealing the section lets lazy accessibility children be materialized before choosing a branch.
            let history = app.descendants(matching: .any)[AXID.activityPersonalRecordsAchievementHistory].firstMatch
            for _ in 0..<20 where !firstTitle.exists && !empty.exists { scroll.swipeUp(velocity: .slow) }
            XCTAssertTrue(history.exists)
            if firstTitle.exists {
                let eventID = String(firstTitle.identifier.dropFirst(titlePrefix.count))
                XCTAssertFalse(eventID.isEmpty)
                captureLeaf(firstTitle, named: "history event title")
                captureLeaf(app.staticTexts["activity-personal-records-achievement-detail-\(eventID)"].firstMatch,
                            named: "history event detail")
                captureLeaf(app.staticTexts["activity-personal-records-achievement-date-\(eventID)"].firstMatch,
                            named: "history event date")
            } else {
                XCTAssertTrue(empty.waitForExistence(timeout: 5), "History should show an event or its real empty state")
                XCTAssertFalse(empty.label.isEmpty)
                captureLeaf(empty, named: "history empty state")
            }
        }
    }

    func testPersonalRecordsPaceHistoryShowsWorkoutsInMonth() throws {
        openActivityDetail(
            sectionIdentifier: AXID.activitySectionPR,
            destinationIdentifier: AXID.activityPersonalRecordsDetailScreen,
            maxSwipes: 24
        )

        let paceChip = app.buttons["activity-personal-records-kind-fastestPace"].firstMatch
        XCTAssertTrue(paceChip.waitForExistence(timeout: 10))
        let chipBar = app.scrollViews["activity-personal-records-chip-bar"].firstMatch
        XCTAssertTrue(chipBar.waitForExistence(timeout: 5))
        for _ in 0..<6 where !paceChip.isHittable { chipBar.swipeLeft() }
        XCTAssertTrue(paceChip.isHittable)
        paceChip.tap()
        let best = app.staticTexts["activity-personal-records-best-value"].firstMatch
        XCTAssertTrue(best.waitForExistence(timeout: 10), "The selected pace should have an all-time best")
        let allTimeBest = best.label
        XCTAssertFalse(allTimeBest.isEmpty)

        let scroll = app.scrollViews[AXID.activityPersonalRecordsDetailScreen].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        let sixMonths = app.buttons["activity-personal-records-period-6M"].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-personal-records-period-6M", maxSwipes: 8))
        sixMonths.tap()
        XCTAssertTrue(sixMonths.isSelected)
        let hero = app.descendants(matching: .any)["activity-personal-records-current-best"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        for _ in 0..<12 where !scroll.frame.intersection(app.windows.firstMatch.frame).contains(hero.frame) {
            if hero.frame.midY < scroll.frame.midY { scroll.swipeDown(velocity: .slow) }
            else { scroll.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(scroll.frame.intersection(app.windows.firstMatch.frame).contains(hero.frame),
                      "The normal-size canonical hero should be fully visible")
        VisualAudit.capture("Personal Records A10 fastest pace six-month hero")
        addScreenshotAttachment(named: "Personal Records A10 fastest pace six-month hero")

        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-personal-records-period-D", maxSwipes: 8))
        let range = app.staticTexts["activity-personal-records-chart-range"].firstMatch
        XCTAssertTrue(range.waitForExistence(timeout: 5))
        var dayRange = ""
        for period in ["D", "W", "M", "6M", "Y"] {
            let control = app.buttons["activity-personal-records-period-\(period)"].firstMatch
            XCTAssertTrue(control.waitForExistence(timeout: 5), "The \(period) period should be available")
            control.tap()
            XCTAssertTrue(control.isSelected, "The \(period) period should become selected")
            XCTAssertEqual(best.label, allTimeBest, "Changing chart period must not change the all-time best")
            XCTAssertFalse(range.label.isEmpty, "The selected period should show its date range")
            if period == "D" { dayRange = range.label }
            if period == "M" { XCTAssertNotEqual(range.label, dayRange, "Day and month ranges should differ") }
        }
        let month = app.buttons["activity-personal-records-period-M"].firstMatch
        month.tap()

        let pacePoint = app.descendants(matching: .any)["personal-records-timeline-latest-value"].firstMatch
        XCTAssertTrue(pacePoint.waitForExistence(timeout: 10),
                      "A recent workout pace should appear in the monthly chart")
        VisualAudit.capture("Personal Records pace history")

        let rewardInfo = app.buttons["activity-personal-records-reward-info"].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("activity-personal-records-reward-info", maxSwipes: 16),
                      "The seeded reward progress should be reachable")
        XCTAssertTrue(rewardInfo.isHittable)
        VisualAudit.capture("Personal Records A10 reward progress")
        addScreenshotAttachment(named: "Personal Records A10 reward progress")

        let historyID = AXID.activityPersonalRecordsAchievementHistory
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(historyID, maxSwipes: 20),
                      "Achievement history should be reachable")
        let history = app.descendants(matching: .any)[historyID].firstMatch
        XCTAssertTrue(history.isHittable)
        VisualAudit.capture("Personal Records A10 achievement history")
        addScreenshotAttachment(named: "Personal Records A10 achievement history")

        tapBackButton()
        ensureActivityRoot()
    }

    func testConsistencyDetailShowsCalendarAndHistorySections() throws {
        try assertSeededConsistencyDetail(maxText: false)
    }

    func testConsistencyDetailAtMaximumAccessibilityTextSize() throws {
        try assertSeededConsistencyDetail(maxText: true)
    }

    private func assertSeededConsistencyDetail(maxText: Bool) throws {
        // TestDataSeeder: manual 30/40/50 minute records on today and the two
        // preceding days. SimulatorAdvancedMockData: qualifying workouts on
        // days 1, 2, 4, 6, 8, 11, 15, 18, 21 and 25 before the reference date.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let qualifyingOffsets = [0, 1, 2, 4, 6, 8, 11, 15, 18, 21, 25]
        let dates = try qualifyingOffsets.map { offset in
            try XCTUnwrap(calendar.date(byAdding: .day, value: -offset, to: today))
        }
        let monthCount = dates.filter { calendar.isDate($0, equalTo: today, toGranularity: .month) }.count
        let start = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: today))
        func dateFormats(_ date: Date) -> [String] {
            [DateFormatter.Style.medium, .long, .full].map { style in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US")
                formatter.calendar = calendar
                formatter.timeZone = calendar.timeZone
                formatter.dateStyle = style
                formatter.timeStyle = .none
                return formatter.string(from: date)
            }
        }

        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        if maxText {
            configuration.additionalArguments.append(contentsOf: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ])
        }
        launchApp(with: configuration)
        openActivityDetail(
            sectionIdentifier: AXID.activitySectionConsistency,
            destinationIdentifier: AXID.activityConsistencyDetailScreen,
            maxSwipes: maxText ? 28 : 10
        )
        let scroll = app.scrollViews[AXID.activityConsistencyDetailScreen].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 15))

        func visibleContent() -> CGRect {
            let base = scroll.frame.intersection(app.windows.firstMatch.frame)
            var top = base.minY
            var bottom = base.maxY
            let navigation = app.navigationBars.firstMatch
            if navigation.exists && !navigation.frame.isEmpty && navigation.frame.intersects(base)
                && navigation.frame.midY < base.midY {
                top = min(bottom, max(top, navigation.frame.maxY))
            }
            let tabBar = app.tabBars.firstMatch
            if tabBar.exists && !tabBar.frame.isEmpty && tabBar.frame.intersects(base)
                && tabBar.frame.midY > base.midY {
                bottom = max(top, min(bottom, tabBar.frame.minY))
            }
            return CGRect(x: base.minX, y: top + 2,
                          width: max(0, base.width), height: max(0, bottom - top - 4))
        }

        func visible(_ identifier: String) -> XCUIElement {
            let element = app.descendants(matching: .any)[identifier].firstMatch
            let dayPrefix = "activity-consistency-day-"
            let requestedDay = identifier.hasPrefix(dayPrefix)
                ? Int(identifier.dropFirst(dayPrefix.count).prefix { $0.isNumber }) : nil
            for _ in 0..<24 {
                let viewport = visibleContent()
                let horizontal = app.scrollViews["activity-consistency-calendar-horizontal"].firstMatch
                let dayViewport = maxText && requestedDay != nil && horizontal.exists
                    ? viewport.intersection(horizontal.frame) : viewport
                if element.exists && !element.frame.isEmpty && dayViewport.contains(element.frame) { break }
                if element.exists && element.frame.maxY > viewport.maxY {
                    scroll.swipeUp(velocity: .slow)
                } else if element.exists && element.frame.minY < viewport.minY {
                    scroll.swipeDown(velocity: .slow)
                } else if maxText, requestedDay != nil, horizontal.exists,
                          !element.frame.isEmpty, !dayViewport.isEmpty {
                    let target = element.frame
                    let overflow = target.minX < dayViewport.minX
                        ? dayViewport.minX - target.minX + 12 : target.maxX - dayViewport.maxX + 12
                    let distance = min(max(overflow, 1), dayViewport.width * 0.35)
                    let start = horizontal.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                        .withOffset(CGVector(dx: dayViewport.midX - horizontal.frame.minX,
                                             dy: target.midY - horizontal.frame.minY))
                    let delta = target.minX < dayViewport.minX ? distance : -distance
                    start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: delta, dy: 0)))
                } else if !element.exists, let requestedDay {
                    // LazyVGrid may not expose offscreen cells until their row is revealed.
                    let cells = app.descendants(matching: .any).matching(
                        NSPredicate(format: "identifier BEGINSWITH %@", dayPrefix)
                    ).allElementsBoundByIndex
                    let days = cells.compactMap { cell in
                        Int(cell.identifier.dropFirst(dayPrefix.count).prefix { $0.isNumber })
                    }
                    if let first = days.min(), requestedDay < first {
                        scroll.swipeDown(velocity: .slow)
                    } else {
                        scroll.swipeUp(velocity: .slow)
                    }
                } else {
                    scroll.swipeUp(velocity: .slow)
                }
            }
            XCTAssertTrue(element.waitForExistence(timeout: 15), "Missing \(identifier)")
            let viewport = visibleContent()
            let horizontal = app.scrollViews["activity-consistency-calendar-horizontal"].firstMatch
            if maxText && requestedDay != nil {
                XCTAssertTrue(horizontal.exists, "Calendar horizontal scroll should exist at maximum text")
            }
            let visibleFrame = maxText && requestedDay != nil && horizontal.exists
                ? viewport.intersection(horizontal.frame) : viewport
            XCTAssertFalse(element.frame.isEmpty, "Empty frame: \(identifier)")
            XCTAssertTrue(visibleFrame.contains(element.frame), "Not fully visible: \(identifier)")
            return element
        }

        XCTAssertEqual(visible("activity-consistency-current-value").label, "3")
        XCTAssertEqual(visible("activity-consistency-best-value").label, "3")
        VisualAudit.capture("A11 consistency current and best \(maxText ? "MAX" : "normal")")
        let day = calendar.component(.day, from: today)
        let todayCell = visible("activity-consistency-day-\(day)-workout-today")
        XCTAssertTrue(dateFormats(today).contains(todayCell.label), todayCell.label)
        XCTAssertEqual(todayCell.value as? String, "Workout")
        if maxText { VisualAudit.capture("A11 consistency today calendar MAX") }
        let monthDays = try XCTUnwrap(calendar.range(of: .day, in: .month, for: today))
        let usedDays = Set(dates.filter { calendar.isDate($0, equalTo: today, toGranularity: .month) }
            .map { calendar.component(.day, from: $0) })
        if maxText {
            let targetDay = 28 // Present in every calendar month and always two digits.
            var components = calendar.dateComponents([.year, .month], from: today)
            components.day = targetDay
            let targetDate = try XCTUnwrap(calendar.date(from: components))
            let suffix = usedDays.contains(targetDay) ? "workout" : "nonqualifying"
            let todaySuffix = targetDay == day ? "-today" : ""
            let cell = visible("activity-consistency-day-\(targetDay)-\(suffix)\(todaySuffix)")
            XCTAssertTrue(dateFormats(targetDate).contains(cell.label), cell.label)
            let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
            let caption = UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: traits)
            let digits = UIFont.monospacedDigitSystemFont(ofSize: caption.pointSize, weight: .regular)
            let requiredWidth = ("28" as NSString).size(withAttributes: [.font: digits]).width
            XCTAssertGreaterThanOrEqual(cell.frame.width + 0.5, requiredWidth,
                                        "Both day digits should fit in the seven-column cell")
            // The day Text has four points of vertical padding on each side.
            XCTAssertLessThanOrEqual(cell.frame.height, max(28, ceil(caption.lineHeight + 8)) + 1,
                                     "The two-digit day should occupy one caption line")
            VisualAudit.capture("A11 consistency two-digit day MAX")
        }
        if let missedDay = monthDays.first(where: { $0 < day && !usedDays.contains($0) }) {
            var components = calendar.dateComponents([.year, .month], from: today)
            components.day = missedDay
            let missedDate = try XCTUnwrap(calendar.date(from: components))
            let missedCell = visible("activity-consistency-day-\(missedDay)-nonqualifying")
            XCTAssertTrue(dateFormats(missedDate).contains(missedCell.label), missedCell.label)
            XCTAssertEqual(missedCell.value as? String, "No workout of 20 minutes or more")
        }
        if let futureDay = monthDays.first(where: { $0 > day }) {
            let futureCell = visible("activity-consistency-day-\(futureDay)-nonqualifying")
            XCTAssertEqual(futureCell.value as? String ?? "", "")
        }
        XCTAssertEqual(visible("activity-consistency-month-progress").label, "\(monthCount)/16")
        VisualAudit.capture("A11 consistency calendar and progress \(maxText ? "MAX" : "normal")")
        let days = visible("activity-consistency-history-days-0")
        XCTAssertTrue(days.label.contains("3"), "Latest streak should span the three seeded days")
        let range = visible("activity-consistency-history-dates-0")
        XCTAssertTrue(dateFormats(start).contains { range.label.contains($0) }, range.label)
        XCTAssertTrue(dateFormats(today).contains { range.label.contains($0) }, range.label)
        VisualAudit.capture("A11 consistency latest history \(maxText ? "MAX" : "normal")")
        XCTAssertFalse(app.descendants(matching: .any)[AXID.activityConsistencyEmptyState].firstMatch.exists)
        tapBackButton()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityToolbarAdd].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(calendar.isDateInToday(today), "Seed and assertions must stay on the same local day")
    }

    func testRecentWorkoutsSeeAllOpensExerciseHistory() throws {
        openExerciseViewFromRecentWorkouts()

        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.exerciseRow(Fixture.benchPressID), maxSwipes: 8),
            "Bench Press row should be reachable in Exercise screen"
        )
        let benchPressRow = app.descendants(matching: .any)[AXID.exerciseRow(Fixture.benchPressID)].firstMatch
        XCTAssertTrue(benchPressRow.waitForExistence(timeout: 8), "Bench Press row should exist in Exercise screen")
        benchPressRow.auditTap()

        let historyLink = app.descendants(matching: .any)[AXID.exerciseSessionViewHistory].firstMatch
        let inspectorClose = app.buttons["exercise-inspector-close"].firstMatch
        XCTAssertTrue(inspectorClose.waitForExistence(timeout: 5), "Selected workout inspector should expose Done\n\(app.debugDescription)")
        XCTAssertTrue(inspectorClose.isHittable, "Workout inspector Done should be reachable\n\(app.debugDescription)")
        inspectorClose.auditTap()
        let inspectorDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: inspectorClose
        )
        XCTAssertEqual(XCTWaiter.wait(for: [inspectorDismissed], timeout: 5), .completed,
                       "Done should close the selected workout inspector")
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseViewScreen].firstMatch.waitForExistence(timeout: 5),
            "Closing the inspector should return to the workout list"
        )
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.exerciseRow(Fixture.benchPressID), maxSwipes: 8),
            "The selected workout should remain accessible after closing its inspector"
        )
        benchPressRow.auditTap()
        let detailScroll = app.scrollViews["exercise-session-detail-scroll"].firstMatch
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5), "Selected workout details should appear\n\(app.debugDescription)")
        for _ in 0..<6 where !historyLink.isHittable { detailScroll.swipeUp() }
        XCTAssertTrue(historyLink.exists && historyLink.isHittable,
                      "Reopening the same workout should make its history reachable\n\(app.debugDescription)")
        historyLink.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseHistoryScreen].firstMatch.waitForExistence(timeout: 10),
            "Exercise history screen should open"
        )
    }

    func testVisualAuditExerciseHistoryFromSelectedWorkout() throws {
        openExerciseViewFromRecentWorkouts()
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.exerciseRow(Fixture.benchPressID), maxSwipes: 8))
        app.descendants(matching: .any)[AXID.exerciseRow(Fixture.benchPressID)].firstMatch.auditTap()

        let historyLink = app.descendants(matching: .any)[AXID.exerciseSessionViewHistory].firstMatch
        let detailScroll = app.scrollViews["exercise-session-detail-scroll"].firstMatch
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5))
        for _ in 0..<8 where !historyLink.isHittable { detailScroll.swipeUp() }
        XCTAssertTrue(historyLink.exists && historyLink.isHittable)
        historyLink.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.exerciseHistoryScreen].firstMatch
            .waitForExistence(timeout: 10))
    }

    func testQuickStartPickerShowsDetailAndSearchResults() throws {
        openQuickStartPicker()

        XCTAssertTrue(app.fillTextInput(AXID.pickerSearchField, with: "Bench Press"), "Picker search should accept Bench Press")
        dismissSearchKeyboardIfPresent()

        let detailButton = app.descendants(matching: .any)[AXID.pickerExerciseDetailButton(Fixture.benchPressID)].firstMatch
        XCTAssertTrue(
            app.scrollToHittablePickerElementIfNeeded(AXID.pickerExerciseDetailButton(Fixture.benchPressID), maxSwipes: 8),
            "Bench Press detail button should be reachable after search"
        )
        XCTAssertTrue(detailButton.waitForExistence(timeout: 8), "Bench Press detail button should exist")
        detailButton.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseDetailScreen].firstMatch.waitForExistence(timeout: 8),
            "Exercise detail sheet should appear"
        )

        let closeButton = app.descendants(matching: .any)[AXID.exerciseDetailClose].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Detail close button should exist")
        closeButton.auditTap()

        XCTAssertTrue(app.fillTextInput(AXID.pickerSearchField, with: "Deadlift"), "Picker search should accept Deadlift")
        dismissSearchKeyboardIfPresent()

        let resultRow = app.descendants(matching: .any)[AXID.pickerExerciseRow(Fixture.deadliftID)].firstMatch
        XCTAssertTrue(
            app.scrollToHittablePickerElementIfNeeded(AXID.pickerExerciseRow(Fixture.deadliftID), maxSwipes: 8),
            "Deadlift result should be reachable after search"
        )
        XCTAssertTrue(resultRow.waitForExistence(timeout: 8), "Deadlift result should appear after search")
    }

    func testRecommendedRoutineCardOpensExerciseStart() throws {
        ensureActivityRoot()
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.activityRecommendedRoutineCard, maxSwipes: 8),
            "Recommended routine card should be reachable"
        )

        let recommendationCard = app.descendants(matching: .any)[AXID.activityRecommendedRoutineCard].firstMatch
        XCTAssertTrue(recommendationCard.waitForExistence(timeout: 8), "Recommended routine card should exist")
        recommendationCard.auditTap()

        let strengthStart = app.descendants(matching: .any)[AXID.exerciseStartScreen].firstMatch
        let cardioStart = app.descendants(matching: .any)[AXID.cardioStartScreen].firstMatch
        XCTAssertTrue(
            strengthStart.waitForExistence(timeout: 3) || cardioStart.waitForExistence(timeout: 7),
            "Tapping a recommended routine should open the appropriate start flow"
        )
    }

    func testActivityAIWorkoutBuilderOpensTemplateForm() throws {
        ensureActivityRoot()
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.activityAIWorkoutBuilder, maxSwipes: 10),
            "AI Workout Builder entry should be reachable from Activity"
        )

        let builderEntry = app.descendants(matching: .any)[AXID.activityAIWorkoutBuilder].firstMatch
        XCTAssertTrue(builderEntry.waitForExistence(timeout: 8), "AI Workout Builder entry should exist")
        builderEntry.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch.waitForExistence(timeout: 8),
            "Template form should open from Activity AI builder entry"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateFormAIPrompt].firstMatch.waitForExistence(timeout: 5),
            "Template form should expose the AI prompt field in create mode"
        )
    }

    func testCrunchCanAddAndRemoveWeightDuringSession() throws {
        openExerciseSingleExercisePicker()
        startQuickStartExerciseFromDetail(search: "Crunch", exerciseID: "crunch")
        let toggle = app.buttons["workout-session-toggle-weight"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        let unit = app.buttons["workout-weight-unit-button"].firstMatch
        XCTAssertTrue(unit.waitForExistence(timeout: 5))
        if unit.label.uppercased().contains("LB") { unit.tap() }
        XCTAssertFalse(app.textFields[AXID.workoutSessionField("kg")].exists)
        toggle.tap()
        let weight = app.textFields[AXID.workoutSessionField("kg")].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertTrue(app.fillTextInput(AXID.workoutSessionField("kg"), with: "10"))
        XCTAssertEqual(weight.value as? String, "10")
        let keyboardDone = app.buttons["workout-keyboard-done-button"].firstMatch
        if keyboardDone.exists { keyboardDone.tap() }
        XCTAssertTrue(unit.waitForExistence(timeout: 5))
        unit.tap()
        let pounds = app.textFields[AXID.workoutSessionField("lb")].firstMatch
        XCTAssertTrue(pounds.waitForExistence(timeout: 5))
        let poundsValue = try XCTUnwrap(Double(try XCTUnwrap(pounds.value as? String)))
        XCTAssertEqual(poundsValue, 22.0462, accuracy: 0.001)
        addScreenshotAttachment(named: "crunch-added-weight-toolbar")
        unit.tap()
        toggle.tap()
        XCTAssertFalse(pounds.exists)
        XCTAssertTrue(app.textFields[AXID.workoutSessionField("reps")].exists)
    }

    func testManualWorkoutSessionSavesAndDismissesCompletionSheet() throws {
        try verifyManualWorkoutCompletion(showsShareSheet: false)
    }

    func testVisualAuditSetRPEAndHelp() throws {
        openQuickStartPicker()
        startQuickStartExerciseFromDetail(search: "Bench Press", exerciseID: Fixture.benchPressID)

        let rpe = app.buttons["set-rpe-activate"].firstMatch
        let slider = app.sliders["set-rpe-slider"].firstMatch
        let controls = app.scrollViews["workout-session-controls"].firstMatch
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        for _ in 0..<12 where !rpe.isHittable && !slider.isHittable {
            controls.swipeUp(velocity: .slow)
        }
        if rpe.isHittable { rpe.auditTap() }
        for _ in 0..<6 where !slider.isHittable {
            controls.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(slider.isHittable, "RPE slider should be visible")
        VisualAudit.capture("RPE active picker")

        let rpeHelp = app.buttons["set-rpe-help"].firstMatch
        for _ in 0..<6 where !rpeHelp.isHittable { controls.swipeUp(velocity: .slow) }
        XCTAssertTrue(rpeHelp.isHittable, "RPE help should be reachable")
        let help = app.buttons["set-rpe-help"].firstMatch
        XCTAssertTrue(help.waitForExistence(timeout: 5))
        help.auditTap()
        XCTAssertTrue(app.scrollViews["rpe-help-sheet"].firstMatch.waitForExistence(timeout: 5))
        VisualAudit.capture("RPE help sheet")
    }

    func testVisualAuditExercisePicker() throws {
        openQuickStartPicker()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
            .waitForExistence(timeout: 8), "Exercise picker should open")
        VisualAudit.capture("Exercise picker initial viewport")
    }

    func testVisualAuditTemplateWorkoutFirstSession() throws {
        openTemplateList()
        let rowID = AXID.workoutTemplateRow(Fixture.circuitTemplate)
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(rowID, maxSwipes: 12))
        let row = app.buttons[rowID].firstMatch
        row.auditTap()
        let container = app.descendants(matching: .any)[AXID.templateWorkoutContainerScreen].firstMatch
        if !container.waitForExistence(timeout: 3) {
            let title = row.staticTexts.firstMatch
            if title.exists && title.isHittable { title.auditTap() }
        }
        XCTAssertTrue(container.waitForExistence(timeout: 8))
        let start = app.buttons[AXID.templateWorkoutTransitionStart].firstMatch
        let session = app.descendants(matching: .any)[AXID.workoutSessionScreen].firstMatch
        XCTAssertTrue(waitForEither(start, session, timeout: 8),
                      "Template should offer Start or open its first session")
        if start.exists { start.auditTap() }
        XCTAssertTrue(app.descendants(matching: .any)[AXID.workoutSessionScreen].firstMatch
            .waitForExistence(timeout: 10), "Template's first workout should open")
        VisualAudit.capture("Template workout first session")
    }

    func testVisualAuditLastSetOptions() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["--ui-design-map-one-set", "-AppleLanguages", "(en)",
                                              "-AppleLocale", "en_US"]
        launchApp(with: configuration)
        openQuickStartPicker()
        startQuickStartExerciseFromDetail(search: "Bench Press", exerciseID: Fixture.benchPressID)

        for control in ["+2.5", "+1"] {
            XCTAssertTrue(scrollToWorkoutControl(control), "\(control) should be reachable")
            app.buttons[control].firstMatch.auditTap()
        }
        let completeSet = app.buttons[AXID.workoutSessionCompleteSet].firstMatch
        XCTAssertTrue(completeSet.waitForExistence(timeout: 5))
        if !completeSet.isHittable {
            XCTAssertTrue(scrollToWorkoutControl(AXID.workoutSessionCompleteSet))
        }
        completeSet.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)["workout-session-last-set-sheet"].firstMatch
            .waitForExistence(timeout: 10), "Last-set options should open after the only set")
        VisualAudit.capture("Last-set options")
    }

    func testVisualAuditRestTimerFromQuickStart() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
        ]
        launchApp(with: configuration)
        openQuickStartPicker()
        startQuickStartExerciseFromDetail(search: "Bench Press", exerciseID: Fixture.benchPressID)
        for control in ["+2.5", "+1"] {
            XCTAssertTrue(scrollToWorkoutControl(control))
            app.buttons[control].firstMatch.auditTap()
        }
        let completeSet = app.buttons[AXID.workoutSessionCompleteSet].firstMatch
        XCTAssertTrue(completeSet.waitForExistence(timeout: 5))
        if !completeSet.isHittable {
            XCTAssertTrue(scrollToWorkoutControl(AXID.workoutSessionCompleteSet))
        }
        completeSet.auditTap()
        XCTAssertTrue(app.buttons["workout-session-add-rest"].firstMatch.waitForExistence(timeout: 10))
        VisualAudit.capture("Rest timer after first completed set")
    }

    func testRestLiveActivityAppearsInNotificationCenterAfterFirstSet() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-fold-audit-long-rest",
            "--ui-test-theme", "desertWarm",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        launchApp(with: configuration)
        openQuickStartPicker()
        startQuickStartExerciseFromDetail(search: "Bench Press", exerciseID: Fixture.benchPressID)
        for control in ["+2.5", "+1"] {
            XCTAssertTrue(scrollToWorkoutControl(control), "\(control) should be reachable")
            app.buttons[control].firstMatch.auditTap()
        }
        let completeSet = app.buttons[AXID.workoutSessionCompleteSet].firstMatch
        XCTAssertTrue(completeSet.waitForExistence(timeout: 5))
        if !completeSet.isHittable {
            XCTAssertTrue(scrollToWorkoutControl(AXID.workoutSessionCompleteSet))
        }
        completeSet.auditTap()
        XCTAssertTrue(app.buttons["workout-session-add-rest"].firstMatch.waitForExistence(timeout: 8),
                      "Completing the first set should start a real rest interval")

        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.01))
        let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.72))
        top.press(forDuration: 0.05, thenDragTo: bottom)

        // A first Live Activity may require system permission; the extension uses
        // SpringBoard's language rather than the app launch locale.
        let allow = springboard.buttons.matching(
            NSPredicate(format: "label IN %@", ["Allow", "허용", "許可"])
        ).firstMatch
        if allow.waitForExistence(timeout: 2) { allow.tap() }

        let title = springboard.staticTexts.matching(
            NSPredicate(format: "label IN %@", ["바벨 벤치프레스", "Barbell Bench Press"])
        ).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 12), "The real Bench Press rest activity should appear")
        let activity = springboard.otherElements.containing(.staticText, identifier: title.label)
            .allElementsBoundByIndex
            .filter { $0.frame.width > 250 && $0.frame.height > 70 && $0.frame.height < 220 }
            .min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        let container = try XCTUnwrap(activity, "SpringBoard should expose the rest activity container")
        let hierarchy = container.debugDescription
        let screenshot = XCTAttachment(screenshot: container.screenshot())
        screenshot.name = "Rest Live Activity notification center"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchyAttachment = XCTAttachment(string: hierarchy)
        hierarchyAttachment.name = "Rest Live Activity system hierarchy"
        hierarchyAttachment.lifetime = .keepAlways
        add(hierarchyAttachment)

        XCTAssertTrue(hierarchy.contains(title.label))
        XCTAssertTrue(["Rest Timer", "휴식 타이머", "休憩タイマー"].contains(where: hierarchy.contains),
                      "The real activity should identify the rest timer")
        XCTAssertTrue(["Set 1", "세트 1", "セット 1"].contains(where: hierarchy.contains),
                      "The real activity should show the completed set")

        let countdown = container.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@ OR value MATCHES %@", ".*[0-9]+:[0-9]{2}.*", ".*[0-9]+:[0-9]{2}.*")
        ).firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 3), "The real countdown should be visible")
        let initialCountdown = countdown.label + String(describing: countdown.value)
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in countdown.exists && countdown.label + String(describing: countdown.value) != initialCountdown },
            object: nil
        )
        let didUpdateAccessibilityLabel = XCTWaiter.wait(for: [changed], timeout: 3) == .completed
        print("Rest Live Activity countdown AX label updated within three seconds: \(didUpdateAccessibilityLabel)")
        app.activate()
        let skipRest = app.buttons["workout-session-skip-rest"].firstMatch
        if skipRest.waitForExistence(timeout: 5) && skipRest.isHittable { skipRest.tap() }

    }

    func testVisualAuditNewExerciseAtDefaultTextSize() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
        ]
        launchApp(with: configuration)
        openTemplateList()
        let addTemplate = app.descendants(matching: .any)[AXID.workoutTemplateListAdd].firstMatch
        XCTAssertTrue(addTemplate.waitForExistence(timeout: 5))
        addTemplate.auditTap()
        let form = app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8))
        let addExercise = app.descendants(matching: .any)[AXID.templateFormAddExercise].firstMatch
        let formScroll = app.collectionViews[AXID.templateFormScreen].firstMatch
        for _ in 0..<12 where !(addExercise.exists && addExercise.isHittable) {
            formScroll.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(addExercise.exists && addExercise.isHittable)
        addExercise.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.pickerRootList].firstMatch.waitForExistence(timeout: 8))
        let create = app.descendants(matching: .any)[AXID.pickerCreateCustomButton].firstMatch
        XCTAssertTrue(app.scrollToHittablePickerElementIfNeeded(AXID.pickerCreateCustomButton, maxSwipes: 12))
        XCTAssertTrue(create.waitForExistence(timeout: 8) && create.isHittable)
        create.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.createCustomExerciseScreen].firstMatch
            .waitForExistence(timeout: 8))
        VisualAudit.capture("New exercise form at default text size")
    }

    func testVisualAuditWorkoutSharePreview() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        try verifyManualWorkoutCompletion(showsShareSheet: true)
    }

    private func verifyManualWorkoutCompletion(showsShareSheet: Bool) throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ])
        launchApp(with: configuration)
        openExerciseSingleExercisePicker()
        startQuickStartExerciseFromDetail(search: "Bench Press", exerciseID: Fixture.benchPressID)

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.workoutSessionScreen].firstMatch.waitForExistence(timeout: 10),
            "Workout session screen should open"
        )

        let sessionControls = app.scrollViews["workout-session-controls"].firstMatch
        XCTAssertTrue(
            sessionControls.waitForExistence(timeout: 5),
            "Workout controls should expose their scroll container\n\(app.debugDescription)"
        )
        let doneButton = app.buttons[AXID.workoutSessionDone].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "Session Done should exist before editing")
        XCTAssertFalse(doneButton.isEnabled, "Starting a session should not complete its first set")

        let weightIncrease = sessionControls.buttons["+2.5"].firstMatch
        XCTAssertTrue(weightIncrease.waitForExistence(timeout: 5), "Weight increment button should exist in current set controls")
        XCTAssertTrue(
            scrollToWorkoutControl("+2.5", mustFitInViewport: true),
            "The whole weight increment should be revealed before hit testing and tapping"
        )
        weightIncrease.auditTap()
        for _ in 0..<6 where !doneButton.exists {
            sessionControls.swipeDown()
        }
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "Done should return after editing weight")
        XCTAssertFalse(
            doneButton.isEnabled,
            "Incrementing weight must not complete a set\n\(app.debugDescription)"
        )

        let repsIncrease = sessionControls.buttons["+1"].firstMatch
        XCTAssertTrue(
            repsIncrease.waitForExistence(timeout: 5),
            "Reps increment button should exist after scrolling. Controls: \(sessionControls.debugDescription)\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            scrollToWorkoutControl("+1", mustFitInViewport: true),
            "The whole reps increment should be revealed before hit testing and tapping"
        )
        repsIncrease.auditTap()
        // Duo collapses the navigation toolbar while the controls scroll.
        // Reveal it before querying the completion action's enabled state.
        for _ in 0..<6 where !doneButton.exists {
            sessionControls.swipeDown()
        }
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "Done should return when scrolling toward the top")
        XCTAssertFalse(doneButton.isEnabled, "Incrementing repetitions must not complete a set\n\(app.debugDescription)")

        let completeSetButton = app.buttons[AXID.workoutSessionCompleteSet].firstMatch
        XCTAssertTrue(completeSetButton.waitForExistence(timeout: 5), "Complete Set button should exist")
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.workoutSessionOverview].firstMatch.exists,
            "Previous workout overview should coexist with current set controls"
        )

        let repsField = app.textFields[AXID.workoutSessionField("reps")].firstMatch
        XCTAssertTrue(repsField.waitForExistence(timeout: 5), "Current set repetitions should be editable")
        XCTAssertTrue(scrollToWorkoutControl(AXID.workoutSessionField("reps"), mustFitInViewport: true),
                      "The whole repetitions input should be revealed before tapping")
        let incrementedReps = try XCTUnwrap(repsField.value as? String, "Repetitions should expose an input value")
        XCTAssertFalse(incrementedReps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Incrementing repetitions should populate the field")
        XCTAssertGreaterThan(Int(incrementedReps) ?? 0, 0, "Incremented repetitions should be valid before completing the set")
        repsField.auditTap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "Repetition entry should open the keyboard")
        XCTAssertTrue(
            completeSetButton.isHittable,
            "Complete Set should remain accessible while entering repetitions\n\(app.debugDescription)"
        )
        XCTAssertTrue(app.windows.firstMatch.frame.contains(completeSetButton.frame),
                      "The whole completion control must remain on screen while editing")
        XCTAssertLessThanOrEqual(completeSetButton.frame.maxY, app.keyboards.firstMatch.frame.minY,
                                 "The completion control must stay above the keyboard")
        VisualAudit.capture("Workout complete set fully above active keyboard")
        completeSetButton.auditTap()

        for _ in 0..<6 where !(doneButton.exists && doneButton.isHittable) {
            sessionControls.swipeDown()
        }
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "Done button should exist")
        let setCompleted = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: doneButton
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [setCompleted], timeout: 5),
            .completed,
            "Done should enable after completing a set. Alerts: \(app.alerts.debugDescription)\n\(app.debugDescription)"
        )
        doneButton.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.workoutCompletionSheet].firstMatch.waitForExistence(timeout: 10),
            "Workout completion sheet should appear"
        )
        // ExerciseDefinition stores this resource name independently of the
        // interface locale; the saved summary uses localizedName, not name.
        let completionSummary = app.staticTexts["\(Fixture.benchPressLocalizedName) · 1 set"].firstMatch
        XCTAssertTrue(completionSummary.waitForExistence(timeout: 5),
                      "Completion should display the saved exercise and set count")

        if showsShareSheet {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded("workout-completion-share", maxSwipes: 6))
            app.buttons["workout-completion-share"].firstMatch.auditTap()
            let sharePreviewTitle = app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@", "\(Fixture.benchPressLocalizedName) Workout")
            ).firstMatch
            XCTAssertTrue(sharePreviewTitle.waitForExistence(timeout: 10),
                          "The system share sheet should show the workout preview title\n\(app.debugDescription)")
            // The completion sheet's Close remains in the AX tree underneath
            // the popover. Target the observed system share header, not that
            // earlier label match in the presenting sheet.
            let shareDismiss = app.buttons["header.closeButton"].firstMatch
            XCTAssertTrue(shareDismiss.waitForExistence(timeout: 5) && shareDismiss.isHittable,
                          "The system share sheet should provide an accessible dismiss control\n\(app.debugDescription)")
            VisualAudit.capture("Workout system share sheet; no recipient selected")
            shareDismiss.auditTap()
            let shareDismissed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: sharePreviewTitle
            )
            XCTAssertEqual(XCTWaiter.wait(for: [shareDismissed], timeout: 8), .completed,
                           "Dismissing system share should remove its preview")
            XCTAssertTrue(app.descendants(matching: .any)[AXID.workoutCompletionSheet].firstMatch
                .waitForExistence(timeout: 5), "Share cancellation should return to workout completion")
            XCTAssertTrue(completionSummary.waitForExistence(timeout: 5),
                          "Share cancellation should preserve the exercise and set summary")
            VisualAudit.capture("Workout completion after dismissing system share")
        }

        let completionDoneButton = app.descendants(matching: .any)[AXID.workoutCompletionDone].firstMatch
        XCTAssertTrue(completionDoneButton.waitForExistence(timeout: 5), "Workout completion done button should exist")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.workoutCompletionDone, maxSwipes: 6))
        completionDoneButton.auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseViewScreen].firstMatch.waitForExistence(timeout: 10),
            "Completion sheet dismissal should return to Exercise root"
        )
    }

    func testWeeklyPlanAssignsTemplateToSelectedDay() throws {
        openTemplateList()
        XCTAssertTrue(app.waitAndTapToolbarAction("workout-weekly-plan-open"),
                      "Templates should expose weekly planning directly or in toolbar overflow\n\(app.debugDescription)")
        let plan = app.descendants(matching: .any)["weekly-workout-plan"].firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 8), "Weekly plan should open")

        let remove = app.buttons["weekly-plan-remove"].firstMatch
        if remove.exists {
            remove.auditTap()
        }

        let assignTemplate = plan.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
            "weekly-plan-template-", Fixture.singleTemplate
        )).firstMatch
        XCTAssertTrue(assignTemplate.waitForExistence(timeout: 5), "Seeded template should be available for assignment")
        let templateList = app.scrollViews["weekly-plan-template-list"].firstMatch
        XCTAssertTrue(templateList.waitForExistence(timeout: 5), "Template pane should expose its scroll container")
        for _ in 0..<4 where !assignTemplate.isHittable {
            templateList.swipeUp()
        }
        XCTAssertTrue(assignTemplate.isHittable, "Template assignment should be accessible without dragging")
        assignTemplate.auditTap()

        let selectedTemplate = app.buttons["weekly-plan-selected-template"].firstMatch
        for _ in 0..<4 where !selectedTemplate.isHittable {
            templateList.swipeDown()
        }
        XCTAssertTrue(selectedTemplate.waitForExistence(timeout: 5), "Selected day should expose its assigned workout")
        XCTAssertTrue(selectedTemplate.label.contains(Fixture.singleTemplate), "Selected day should use the chosen template")
        XCTAssertTrue(app.waitAndTap("weekly-plan-remove"), "Assigned workout should be removable from the plan")
        let assignmentRemoved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: selectedTemplate
        )
        XCTAssertEqual(XCTWaiter.wait(for: [assignmentRemoved], timeout: 5), .completed,
                       "Removing the assignment should restore the selected day to a rest day")
        XCTAssertTrue(assignTemplate.exists, "Removing a plan assignment must preserve the template")
    }

    func testTemplateListSupportsCreateEditAndTemplateStart() throws {
        if VisualAudit.isEnabled {
            executionTimeAllowance = 600
            var configuration = launchConfiguration
            configuration.additionalArguments += [
                "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ]
            launchApp(with: configuration)
            XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        }
        openTemplateList()

        func revealWholeRow(_ row: XCUIElement, in list: XCUIElement, preferUp: Bool, maxDrags: Int = 16) -> Bool {
            guard list.waitForExistence(timeout: 5) else { return false }
            for _ in 0..<maxDrags {
                let viewport = list.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 80)
                if row.exists && viewport.contains(row.frame) && row.isHittable { return true }
                let moveUp = row.exists ? row.frame.midY >= viewport.midY : preferUp
                let startY: CGFloat = moveUp ? 0.72 : 0.28
                let endY: CGFloat = moveUp ? 0.47 : 0.53
                list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                    .press(forDuration: 0.05, thenDragTo: list.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: endY)
                    ), withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            let viewport = list.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 80)
            return row.exists && viewport.contains(row.frame) && row.isHittable
        }

        let addButton = app.descendants(matching: .any)[AXID.workoutTemplateListAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Template add button should exist")
        addButton.auditTap()

        let templateForm = app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch
        XCTAssertTrue(templateForm.waitForExistence(timeout: 8), "Template form should appear")

        let saveButton = app.buttons[AXID.templateFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Template save button should exist")
        XCTAssertFalse(saveButton.isEnabled, "Template save should be disabled without name and entries")

        let addExercise = app.buttons[AXID.templateFormAddExercise].firstMatch
        let formScroll = app.collectionViews[AXID.templateFormScreen].firstMatch
        XCTAssertTrue(formScroll.waitForExistence(timeout: 5), "Template form should expose its scroll viewport")
        for _ in 0..<12 {
            let viewport = formScroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 12)
            if addExercise.exists && viewport.contains(addExercise.frame) && addExercise.isHittable { break }
            if addExercise.exists && addExercise.frame.midY < viewport.midY {
                formScroll.swipeDown(velocity: .slow)
            } else {
                formScroll.swipeUp(velocity: .slow)
            }
        }
        XCTAssertTrue(addExercise.exists && addExercise.isHittable
                      && formScroll.frame.intersection(app.windows.firstMatch.frame)
                        .insetBy(dx: 8, dy: 12).contains(addExercise.frame),
                      "The whole Add Exercise button should be revealed before tapping")
        VisualAudit.capture("Template form revealed Add Exercise row at maximum AX")
        addExercise.auditTap()

        let createCustomButton = app.descendants(matching: .any)[AXID.pickerCreateCustomButton].firstMatch
        XCTAssertTrue(createCustomButton.waitForExistence(timeout: 8), "Create custom button should exist in full picker")
        createCustomButton.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.createCustomExerciseScreen].firstMatch.waitForExistence(timeout: 8),
            "Create custom exercise screen should appear"
        )
        XCTAssertTrue(
            app.fillTextInput(AXID.createCustomExerciseName, with: Fixture.customExercise),
            "Custom exercise name should be editable"
        )
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists {
            let returnKey = keyboard.buttons["Return"].firstMatch
            XCTAssertTrue(returnKey.waitForExistence(timeout: 3) && returnKey.isHittable,
                          "The custom exercise name keyboard should expose Return")
            returnKey.auditTap()
            let keyboardDismissed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: keyboard
            )
            XCTAssertEqual(XCTWaiter.wait(for: [keyboardDismissed], timeout: 5), .completed,
                           "Return should dismiss the keyboard before revealing muscles")
        }
        XCTAssertEqual(app.textFields[AXID.createCustomExerciseName].firstMatch.value as? String,
                       Fixture.customExercise, "Dismissing the keyboard should preserve the custom name")
        let shouldersChip = app.buttons[AXID.createCustomExerciseMuscle("shoulders")].firstMatch
        let customForm = app.collectionViews[AXID.createCustomExerciseScreen].firstMatch
        XCTAssertTrue(revealWholeRow(shouldersChip, in: customForm, preferUp: true, maxDrags: 20),
                      "The whole Shoulders chip should be revealed below the form's input controls")
        if VisualAudit.isEnabled {
            let musclesHeading = app.staticTexts["Primary Muscles"].firstMatch
            XCTAssertTrue(musclesHeading.exists, "The muscle section heading should provide a text-height reference")
            XCTAssertEqual(shouldersChip.label, "Shoulders", "The full muscle label should remain exposed")
            XCTAssertLessThanOrEqual(shouldersChip.frame.height, musclesHeading.frame.height,
                                     "Shoulders should not stack into more lines than the two-word section heading")
            XCTAssertGreaterThan(shouldersChip.frame.width, shouldersChip.frame.height,
                                 "The Shoulders chip should stay wider than its text stack")
        }
        VisualAudit.capture("Custom exercise Shoulders chip fully revealed above keyboard area")
        shouldersChip.auditTap()
        app.descendants(matching: .any)[AXID.createCustomExerciseCreate].firstMatch.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch.waitForExistence(timeout: 8),
            "Template form should return after custom exercise creation"
        )
        let templateName = app.textFields[AXID.templateFormName].firstMatch
        XCTAssertTrue(revealWholeRow(templateName, in: formScroll, preferUp: false),
                      "Template name should be reachable after returning from custom exercise creation")
        XCTAssertTrue(app.fillTextInput(AXID.templateFormName, with: Fixture.createdTemplate), "Template name should be editable")
        XCTAssertTrue(saveButton.isEnabled, "Template save should enable after required inputs")
        saveButton.auditTap()

        let createdTemplateRow = app.buttons[AXID.workoutTemplateRow(Fixture.createdTemplate)].firstMatch
        let templateList = app.collectionViews[AXID.workoutTemplateListScreen].firstMatch
        XCTAssertTrue(revealWholeRow(createdTemplateRow, in: templateList, preferUp: false),
                      "Created template should appear as a whole row in the list")

        let seedCell = app.buttons[AXID.workoutTemplateRow(Fixture.singleTemplate)].firstMatch
        XCTAssertTrue(revealWholeRow(seedCell, in: templateList, preferUp: true),
                      "Seeded single template should be fully reachable for editing")
        seedCell.swipeRight()

        let editButton = app.buttons[AXID.workoutTemplateEdit(Fixture.singleTemplate)].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit swipe action should appear")
        editButton.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch.waitForExistence(timeout: 8),
            "Edit template form should appear"
        )
        XCTAssertTrue(revealWholeRow(templateName, in: formScroll, preferUp: false),
                      "Existing template name should be reachable for editing")
        XCTAssertTrue(app.fillTextInput(AXID.templateFormName, with: Fixture.updatedTemplate), "Seeded template name should be editable")
        app.buttons[AXID.templateFormSave].firstMatch.auditTap()

        let updatedRow = app.buttons[AXID.workoutTemplateRow(Fixture.updatedTemplate)].firstMatch
        XCTAssertTrue(revealWholeRow(updatedRow, in: templateList, preferUp: false),
                      "Updated template should appear as a whole row")

        let circuitTemplate = app.buttons[AXID.workoutTemplateRow(Fixture.circuitTemplate)].firstMatch
        XCTAssertTrue(revealWholeRow(circuitTemplate, in: templateList, preferUp: true),
                      "Seeded circuit template should be fully reachable before starting")
        XCTAssertTrue(circuitTemplate.label.contains("Squat") && circuitTemplate.label.contains("Bench Press"),
                      "Seeded circuit should list both expected exercises before starting")
        if VisualAudit.isEnabled {
            VisualAudit.capture("Circuit Builder list row with Squat and Bench Press")
        }
        circuitTemplate.auditTap()
        if VisualAudit.isEnabled {
            let container = app.descendants(matching: .any)[AXID.templateWorkoutContainerScreen].firstMatch
            if !container.waitForExistence(timeout: 2) {
                // Keep the row-center failure evidence, then test a painted label.
                let title = circuitTemplate.staticTexts.firstMatch
                if title.exists && title.isHittable { title.auditTap() }
            }
        }

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateWorkoutContainerScreen].firstMatch.waitForExistence(timeout: 10),
            "Template workout container should open for multi-exercise template"
        )
        if VisualAudit.isEnabled {
            let sessionProgress = app.staticTexts.matching(NSPredicate(
                format: "identifier == %@ AND label == %@", AXID.workoutSessionScreen, "Exercise 1 of 2"
            )).firstMatch
            XCTAssertTrue(app.navigationBars[Fixture.circuitTemplate].firstMatch.waitForExistence(timeout: 5)
                          || sessionProgress.waitForExistence(timeout: 2),
                          "The presented container should retain the selected circuit identity")
            VisualAudit.capture("Circuit Builder workout container with first exercise")
        }
        let transitionStart = app.buttons[AXID.templateWorkoutTransitionStart].firstMatch
        let workoutSessionDone = app.buttons[AXID.workoutSessionDone].firstMatch
        XCTAssertTrue(
            waitForEither(transitionStart, workoutSessionDone, timeout: 8),
            "Template workflow should expose a transition start CTA or enter the workout session directly"
        )
        if transitionStart.exists {
            if VisualAudit.isEnabled {
                XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: 4, dy: 4).contains(transitionStart.frame),
                              "The whole template Start action should fit in the window")
            }
            transitionStart.auditTap()
        }

        XCTAssertTrue(
            workoutSessionDone.waitForExistence(timeout: 10),
            "Starting the template transition should enter the workout session lane"
        )
        XCTAssertTrue(app.staticTexts["Exercise 1 of 2"].firstMatch.waitForExistence(timeout: 5),
                      "The workout should retain two-exercise template progress")
        XCTAssertTrue(app.staticTexts["바벨 스쿼트"].firstMatch.waitForExistence(timeout: 5),
                      "The workout session should begin with the circuit's first library exercise")
        VisualAudit.capture("Circuit Builder first workout session with two-exercise progress")
    }

    func testVisualAuditCustomMuscleChipFoldReadability() throws {
        guard VisualAudit.isEnabled,
              ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_FOLD"] == "1" else {
            throw XCTSkip("Opt-in native custom muscle chip fold audit only")
        }
        executionTimeAllowance = 600
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        openTemplateList()

        func revealWhole(_ element: XCUIElement, in scroll: XCUIElement, maxDrags: Int = 20) -> Bool {
            guard scroll.waitForExistence(timeout: 5) else { return false }
            let navigationTitle = scroll.identifier == AXID.templateFormScreen ? "New Template" : "New Exercise"
            let navigationBar = app.navigationBars[navigationTitle].firstMatch
            func viewport() -> CGRect {
                let base = scroll.frame.intersection(app.windows.firstMatch.frame)
                let top = max(base.minY, navigationBar.exists ? navigationBar.frame.maxY + 4 : base.minY + 80)
                return CGRect(x: base.minX + 8, y: top, width: max(0, base.width - 16),
                              height: max(0, base.maxY - 12 - top))
            }
            for attempt in 0..<maxDrags {
                let visible = viewport()
                if element.exists && visible.contains(element.frame) && element.isHittable { return true }
                let moveUp = element.exists ? element.frame.midY >= visible.midY : attempt < maxDrags / 2
                let startY: CGFloat = moveUp ? 0.72 : 0.28
                let endY: CGFloat = moveUp ? 0.47 : 0.53
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                    .press(forDuration: 0.05, thenDragTo: scroll.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: endY)
                    ), withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            return element.exists && viewport().contains(element.frame) && element.isHittable
        }

        let listAdd = app.buttons[AXID.workoutTemplateListAdd].firstMatch
        XCTAssertTrue(listAdd.waitForExistence(timeout: 5) && listAdd.isHittable)
        listAdd.auditTap()
        let form = app.collectionViews[AXID.templateFormScreen].firstMatch
        let addExercise = app.buttons[AXID.templateFormAddExercise].firstMatch
        XCTAssertTrue(revealWhole(addExercise, in: form), "Add Exercise should be wholly reachable in the form")
        addExercise.auditTap()
        let createCustom = app.buttons[AXID.pickerCreateCustomButton].firstMatch
        XCTAssertTrue(createCustom.waitForExistence(timeout: 8) && createCustom.isHittable)
        createCustom.auditTap()

        let customForm = app.collectionViews[AXID.createCustomExerciseScreen].firstMatch
        let shoulders = app.buttons[AXID.createCustomExerciseMuscle("shoulders")].firstMatch
        XCTAssertTrue(revealWhole(shoulders, in: customForm), "Shoulders should be reachable in the custom form")
        let heading = app.staticTexts["Primary Muscles"].firstMatch
        XCTAssertTrue(heading.exists && heading.frame.height > 0,
                      "The two-word section heading should provide a measured text-height reference")
        let headingHeight = heading.frame.height

        for state in ["closed", "openFlat", "partiallyOpen"] {
            VisualAudit.capture("FOLD:\(state)")
            XCTAssertTrue(revealWhole(shoulders, in: customForm),
                          "The whole Shoulders chip should remain reachable after \(state)")
            XCTAssertEqual(shoulders.label, "Shoulders", "The full muscle label should remain exposed")
            XCTAssertLessThanOrEqual(shoulders.frame.height, headingHeight,
                                     "Shoulders should not form a multi-character vertical stack in \(state)")
            XCTAssertGreaterThan(shoulders.frame.width, shoulders.frame.height,
                                 "The Shoulders chip should remain wider than its label stack in \(state)")
            VisualAudit.capture("Custom exercise \(state) full Shoulders chip and label")
        }

        let customCancel = app.navigationBars["New Exercise"].buttons["Cancel"].firstMatch
        XCTAssertTrue(customCancel.waitForExistence(timeout: 5) && customCancel.isHittable)
        customCancel.auditTap()
        let pickerCancel = app.buttons[AXID.pickerCancelButton].firstMatch
        XCTAssertTrue(pickerCancel.waitForExistence(timeout: 5) && pickerCancel.isHittable)
        pickerCancel.auditTap()
        let formCancel = app.buttons[AXID.templateFormCancel].firstMatch
        XCTAssertTrue(formCancel.waitForExistence(timeout: 5) && formCancel.isHittable)
        formCancel.auditTap()
        XCTAssertTrue(app.collectionViews[AXID.workoutTemplateListScreen].firstMatch.waitForExistence(timeout: 8),
                      "Cancel should return to the template list without saving a test exercise")
    }

    func testTemplateWorkoutContainerCloseDismissesFullScreenFlow() throws {
        openTemplateList()

        let circuitTemplate = app.buttons[AXID.workoutTemplateRow(Fixture.circuitTemplate)].firstMatch
        XCTAssertTrue(circuitTemplate.waitForExistence(timeout: 8), "Seeded multi template should exist")
        circuitTemplate.auditTap()
        if VisualAudit.isEnabled {
            let container = app.descendants(matching: .any)[AXID.templateWorkoutContainerScreen].firstMatch
            if !container.waitForExistence(timeout: 2) {
                // Keep the row-center failure evidence, then test a painted label.
                let title = circuitTemplate.staticTexts.firstMatch
                if title.exists && title.isHittable { title.auditTap() }
            }
        }

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateWorkoutContainerScreen].firstMatch.waitForExistence(timeout: 10),
            "Template workout container should open for multi-exercise template"
        )

        let closeButton = app.buttons[AXID.templateWorkoutContainerClose].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Template container close button should exist")
        closeButton.auditTap()

        let endTemplate = app.buttons[AXID.templateWorkoutContainerEnd].firstMatch
        XCTAssertTrue(endTemplate.waitForExistence(timeout: 5), "Template end confirmation should appear")
        endTemplate.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.workoutTemplateListScreen].firstMatch.waitForExistence(timeout: 10),
            "Ending the template flow should return to the template list"
        )
    }

    func testCompoundWorkoutSetupStartsWorkoutAndFinishesFlow() throws {
        openExerciseViewFromRecentWorkouts()

        let addMenu = app.descendants(matching: .any)[AXID.exerciseToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Exercise add menu should exist")
        addMenu.auditTap()

        let compoundOption = app.descendants(matching: .any)[AXID.exerciseMenuCompound].firstMatch
        XCTAssertTrue(compoundOption.waitForExistence(timeout: 5), "Superset / Circuit menu item should exist")
        compoundOption.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.compoundWorkoutSetupScreen].firstMatch.waitForExistence(timeout: 8),
            "Compound workout setup should appear"
        )

        addCompoundExercise(Fixture.benchPressID)
        addCompoundExercise("barbell-squat")

        let selectionCount = app.descendants(matching: .any)[AXID.compoundWorkoutSetupSelectionCount].firstMatch
        XCTAssertTrue(selectionCount.waitForExistence(timeout: 5), "Compound setup selection count should exist")
        XCTAssertEqual(selectionCount.label, "Exercises (2)", "Compound setup should reflect both selected exercises")

        let setupScroll = app.collectionViews[AXID.compoundWorkoutSetupScreen].firstMatch
        let startCandidate = app.buttons[AXID.compoundWorkoutSetupStart].firstMatch
        for _ in 0..<8 where !(startCandidate.exists && startCandidate.isHittable) {
            setupScroll.swipeUp()
        }
        VisualAudit.capture("Compound setup with reachable Start")
        let startButtons = app.descendants(matching: .any)
            .matching(identifier: AXID.compoundWorkoutSetupStart)
            .allElementsBoundByIndex
        let startButton = startButtons.last ?? app.descendants(matching: .any)[AXID.compoundWorkoutSetupStart].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Compound start button should exist")
        XCTAssertTrue(
            waitForEnabled(startButton, timeout: 5),
            "Compound start should enable after two selections"
        )
        startButton.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.compoundWorkoutScreen].firstMatch.waitForExistence(timeout: 10),
            "Compound workout screen should open"
        )
        VisualAudit.capture("Compound workout active session")

        XCTAssertTrue(
            app.fillTextInput(AXID.setRowField(1, "weight"), with: "60"),
            "Compound workout first set weight should be editable"
        )
        XCTAssertTrue(
            app.fillTextInput(AXID.setRowField(1, "reps"), with: "8"),
            "Compound workout first set reps should be editable"
        )
        XCTAssertEqual(app.textFields[AXID.setRowField(1, "weight")].value as? String, "60")
        XCTAssertEqual(app.textFields[AXID.setRowField(1, "reps")].value as? String, "8")
        VisualAudit.capture("Compound edited values with keyboard")

        let completeSetButton = app.buttons[AXID.setRowComplete(1)].firstMatch
        XCTAssertTrue(completeSetButton.waitForExistence(timeout: 5), "Compound workout complete-set button should exist")
        completeSetButton.auditTap()

        if VisualAudit.isEnabled {
            let sessionScroll = app.scrollViews[AXID.compoundWorkoutScreen].firstMatch
            let skipRest = app.buttons["rest-timer-skip"].firstMatch
            for _ in 0..<16 where !(skipRest.exists && skipRest.isHittable) {
                sessionScroll.swipeUp()
            }
            XCTAssertTrue(skipRest.exists && skipRest.isHittable, "Rest timer Skip must be reachable after completing a set")
            VisualAudit.capture("Compound rest timer with reachable Skip")
            skipRest.auditTap()
        }
        let finishButton = app.buttons[AXID.compoundWorkoutFinish].firstMatch
        for _ in 0..<16 where !(finishButton.exists && finishButton.isHittable) {
            app.scrollViews[AXID.compoundWorkoutScreen].firstMatch.swipeDown()
        }
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5), "Compound workout finish button should exist")
        XCTAssertTrue(waitForEnabled(finishButton, timeout: 5), "Compound workout finish button should enable after one completed set")
        finishButton.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.workoutCompletionSheet].firstMatch.waitForExistence(timeout: 10),
            "Finishing a compound workout should show the completion sheet"
        )
    }

    func testCardioFlowReachesSummary() throws {
        try verifyCardioFlowReachesSummary(accessibilityText: true)
    }

    func testStairClimberLevelChangesAppearInSummary() throws {
        openQuickStartPicker()
        XCTAssertTrue(app.fillTextInput(AXID.pickerSearchField, with: "천국의 계단"))
        dismissSearchKeyboardIfPresent()

        let detailID = AXID.pickerExerciseDetailButton("stair-climber")
        XCTAssertTrue(app.scrollToHittablePickerElementIfNeeded(detailID, maxSwipes: 8))
        app.descendants(matching: .any)[detailID].firstMatch.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.exerciseDetailScreen].firstMatch.waitForExistence(timeout: 8))
        app.descendants(matching: .any)[AXID.exerciseDetailStart].firstMatch.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.cardioStartScreen].firstMatch.waitForExistence(timeout: 8))
        app.buttons[AXID.cardioStartIndoor].firstMatch.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.cardioSessionScreen].firstMatch.waitForExistence(timeout: 10))

        let increase = app.buttons["cardio-level-increase"].firstMatch
        XCTAssertTrue(increase.waitForExistence(timeout: 5))
        increase.auditTap()
        increase.auditTap()
        XCTAssertEqual(app.staticTexts["cardio-level-value"].firstMatch.label, "3")

        app.buttons[AXID.cardioSessionEnd].firstMatch.auditTap()
        app.buttons[AXID.cardioSessionConfirmEnd].firstMatch.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.cardioSessionSummaryScreen].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["cardio-level-history-row-0"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["cardio-level-history-row-1"].firstMatch.exists)
    }

    func testVisualAuditCardioAtDefaultTextSize() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        try verifyCardioFlowReachesSummary(accessibilityText: false)
    }

    private func verifyCardioFlowReachesSummary(accessibilityText: Bool) throws {
        if VisualAudit.isEnabled {
            var configuration = launchConfiguration
            configuration.additionalArguments += [
                "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-UIPreferredContentSizeCategoryName",
                accessibilityText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"
            ]
            launchApp(with: configuration)
            XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        }
        openQuickStartPicker()
        XCTAssertTrue(app.fillTextInput(AXID.pickerSearchField, with: "Running"), "Picker search should accept Running")
        dismissSearchKeyboardIfPresent()

        let detailButton = app.descendants(matching: .any)[AXID.pickerExerciseDetailButton(Fixture.runningID)].firstMatch
        XCTAssertTrue(
            app.scrollToHittablePickerElementIfNeeded(AXID.pickerExerciseDetailButton(Fixture.runningID), maxSwipes: 8),
            "Running detail button should be reachable"
        )
        XCTAssertTrue(detailButton.waitForExistence(timeout: 8), "Running detail button should exist")
        detailButton.auditTap()

        let detailScreen = app.descendants(matching: .any)[AXID.exerciseDetailScreen].firstMatch
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 8), "Exercise detail sheet should appear for Running")

        let detailStartButton = app.descendants(matching: .any)[AXID.exerciseDetailStart].firstMatch
        XCTAssertTrue(detailStartButton.waitForExistence(timeout: 5), "Exercise detail start button should exist")
        detailStartButton.auditTap()

        let cardioStartScreen = app.descendants(matching: .any)[AXID.cardioStartScreen].firstMatch
        XCTAssertTrue(cardioStartScreen.waitForExistence(timeout: 10), "Cardio start sheet should appear")

        let indoorButton = app.buttons[AXID.cardioStartIndoor].firstMatch
        XCTAssertTrue(indoorButton.waitForExistence(timeout: 5), "Indoor cardio start button should exist")
        indoorButton.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.cardioSessionScreen].firstMatch.waitForExistence(timeout: 10),
            "Cardio session should start"
        )

        let cardioSessionEndButton = app.descendants(matching: .any)[AXID.cardioSessionEnd].firstMatch
        XCTAssertTrue(cardioSessionEndButton.waitForExistence(timeout: 5), "Cardio end button should exist")
        cardioSessionEndButton.auditTap()
        let endWorkout = app.descendants(matching: .any)[AXID.cardioSessionConfirmEnd].firstMatch
        XCTAssertTrue(endWorkout.waitForExistence(timeout: 5), "End Workout confirmation should appear")
        endWorkout.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.cardioSessionSummaryScreen].firstMatch.waitForExistence(timeout: 10),
            "Cardio summary should appear after ending session"
        )

        let systemAlert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if systemAlert.exists {
            let allow = systemAlert.buttons.matching(NSPredicate(
                format: "label IN %@", ["Allow", "허용", "許可"]
            )).firstMatch
            if allow.exists { allow.tap() }
        }
        if VisualAudit.isEnabled {
            XCTAssertTrue(app.staticTexts["Workout Complete!"].firstMatch.waitForExistence(timeout: 8),
                          "Summary title should render after the permission dialog is handled")
        }
        let save = app.buttons["cardio-session-summary-save"].firstMatch
        XCTAssertTrue(waitForHittable(save, timeout: 5), "Summary Save must be reachable\n\(app.debugDescription)")
        XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: 4, dy: 4).contains(save.frame),
                      "The whole summary Save action should fit above the window edge")
        VisualAudit.capture("Cardio summary top title and full Save after permission dismissal")
        if VisualAudit.isEnabled {
            let summaryScroll = app.descendants(matching: .any)[AXID.cardioSessionSummaryScreen].firstMatch.scrollViews.firstMatch
            XCTAssertTrue(summaryScroll.waitForExistence(timeout: 5), "Cardio summary should own a metric scroll view")
            for (metric, checkpoint) in [("Steps", "steps"), ("Cadence", "cadence")] {
                let label = app.staticTexts[metric].firstMatch
                for _ in 0..<8 {
                    let viewport = summaryScroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 8)
                    if label.exists && viewport.contains(CGPoint(x: label.frame.midX, y: label.frame.midY)) { break }
                    summaryScroll.swipeUp(velocity: .slow)
                }
                let viewport = summaryScroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 8)
                XCTAssertTrue(label.exists && viewport.contains(CGPoint(x: label.frame.midX, y: label.frame.midY)),
                              "Cardio summary \(checkpoint) should reach the visible scroll viewport")
                XCTAssertTrue(save.isHittable, "Save should remain reachable while reviewing summary metrics")
                XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: 4, dy: 4).contains(save.frame),
                              "Summary Save should remain wholly visible while metrics scroll")
                VisualAudit.capture("Cardio summary lower \(checkpoint) and full Save")
            }
        }
    }

    func testUserCategoryManagementCreatesCategory() throws {
        openExerciseViewFromRecentWorkouts()

        let categoriesButton = app.descendants(matching: .any)[AXID.exerciseToolbarCategories].firstMatch
        XCTAssertTrue(categoriesButton.waitForExistence(timeout: 5), "Categories toolbar button should exist")
        categoriesButton.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.userCategoryManagementScreen].firstMatch.waitForExistence(timeout: 8),
            "User category management should appear"
        )

        app.descendants(matching: .any)[AXID.userCategoryAdd].firstMatch.auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.userCategoryEditScreen].firstMatch.waitForExistence(timeout: 8),
            "Category edit screen should appear"
        )
        XCTAssertTrue(app.fillTextInput(AXID.userCategoryName, with: Fixture.createdCategory), "Category name should be editable")
        app.descendants(matching: .any)[AXID.userCategorySave].firstMatch.auditTap()

        XCTAssertTrue(app.staticTexts[Fixture.createdCategory].firstMatch.waitForExistence(timeout: 8), "Created category should appear")
    }

    func testNotificationWorkoutRouteOpensMockWorkoutDetail() throws {
        openNotificationHub()

        let workoutRouteRow = app.buttons[AXID.notificationWorkoutRow(Fixture.notificationWorkoutRouteID)].firstMatch
        XCTAssertTrue(workoutRouteRow.waitForExistence(timeout: 8), "Workout route notification should exist")
        workoutRouteRow.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.healthkitWorkoutDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Mock HealthKit workout detail should open from notification"
        )
    }

    func testNotificationWorkoutRouteOpensHealthKitDetailAndTitleEditor() throws {
        openNotificationHub()

        let workoutRouteRow = app.buttons[AXID.notificationWorkoutRow(Fixture.notificationWorkoutRouteID)].firstMatch
        XCTAssertTrue(workoutRouteRow.waitForExistence(timeout: 8), "Workout route notification should exist")
        workoutRouteRow.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.healthkitWorkoutDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "HealthKit workout detail should open from the notification workout route"
        )

        let editTitleButton = app.buttons[AXID.healthkitWorkoutEditTitle].firstMatch
        XCTAssertTrue(editTitleButton.waitForExistence(timeout: 5), "HealthKit workout detail should expose the edit title action")
        editTitleButton.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.healthkitWorkoutTitleEditorScreen].firstMatch.waitForExistence(timeout: 8),
            "HealthKit title editor should appear"
        )
        XCTAssertTrue(
            app.fillTextInput(AXID.healthkitWorkoutTitleField, with: "Codex Route Title"),
            "HealthKit workout title field should be editable"
        )

        let saveButton = app.buttons[AXID.healthkitWorkoutTitleSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "HealthKit title editor save button should exist")
        saveButton.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.healthkitWorkoutDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Saving the title edit should return to the HealthKit workout detail"
        )
    }

    func testVisualAuditHeartRateRecoveryExplanation() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append("--ui-design-map-heart-rate-recovery")
        launchApp(with: configuration)
        openNotificationHub()
        let route = app.buttons[AXID.notificationWorkoutRow(Fixture.notificationWorkoutRouteID)].firstMatch
        XCTAssertTrue(route.waitForExistence(timeout: 8))
        route.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.healthkitWorkoutDetailScreen].firstMatch
            .waitForExistence(timeout: 10))

        let infoID = "heart-rate-recovery-info-button"
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(infoID, maxSwipes: 10))
        app.buttons[infoID].firstMatch.auditTap()
        XCTAssertTrue(app.scrollViews["heart-rate-recovery-info-sheet"].firstMatch
            .waitForExistence(timeout: 5))
        VisualAudit.capture("Heart rate recovery explanation")
    }

    func testNotificationMissingWorkoutRouteShowsFallback() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        launchApp(with: configuration)
        openNotificationHub()

        let missingRouteRow = app.buttons[AXID.notificationWorkoutRow(Fixture.notificationMissingRouteID)].firstMatch
        XCTAssertTrue(missingRouteRow.waitForExistence(timeout: 8), "Missing route notification should exist")
        missingRouteRow.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.notificationTargetNotFoundScreen].firstMatch.waitForExistence(timeout: 10),
            "Missing workout route should open fallback screen"
        )
        XCTAssertEqual(app.staticTexts["notification-target-not-found-title"].firstMatch.label,
                       "Exercise not found")
        XCTAssertEqual(app.staticTexts["notification-target-not-found-message"].firstMatch.label,
                       "The notification target has been deleted or is not synced.")
        XCTAssertEqual(app.staticTexts["notification-target-not-found-id"].firstMatch.label,
                       "ID: \(Fixture.notificationMissingRouteID)")
        addScreenshotAttachment(named: "T14 missing workout target before Back")
        VisualAudit.capture("T14 missing workout target before Back")
    }

    func testNotificationMissingWorkoutRouteDarkMaximumAccessibilitySize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "--ui-test-style", "dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        openNotificationHub()

        let missingRouteRow = app.buttons[AXID.notificationWorkoutRow(Fixture.notificationMissingRouteID)].firstMatch
        XCTAssertTrue(t14RevealMissingWorkoutRouteRow(missingRouteRow),
                      "The missing workout notification should be reachable in the front hub list")
        missingRouteRow.auditTap()

        let scroll = app.scrollViews[AXID.notificationTargetNotFoundScreen].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 10), "The front fallback scroll should open")
        let title = app.staticTexts["notification-target-not-found-title"].firstMatch
        let message = app.staticTexts["notification-target-not-found-message"].firstMatch
        let identifier = app.staticTexts["notification-target-not-found-id"].firstMatch
        XCTAssertEqual(title.label, "Exercise not found")
        XCTAssertEqual(message.label, "The notification target has been deleted or is not synced.")
        XCTAssertEqual(identifier.label, "ID: \(Fixture.notificationMissingRouteID)")

        t14RevealFallbackText(title, in: scroll, position: .whole)
        addScreenshotAttachment(named: "T14 dark maximum text title")
        VisualAudit.capture("T14 dark maximum text title")
        t14RevealFallbackText(message, in: scroll, position: .start)
        addScreenshotAttachment(named: "T14 dark maximum text message start")
        t14RevealFallbackText(message, in: scroll, position: .end)
        addScreenshotAttachment(named: "T14 dark maximum text message end")
        // Selectable Text reports its AX origin at the scroll edge despite inset glyphs.
        // Keep the ID inside the actual clip bounds without a synthetic 4-point inset.
        t14RevealFallbackText(identifier, in: scroll, position: .whole, horizontalInset: 0)
        addScreenshotAttachment(named: "T14 dark maximum text actual ID before Back")
        VisualAudit.capture("T14 dark maximum text actual ID before Back")

        tapBackButton()
        XCTAssertTrue(scroll.waitForNonExistence(timeout: 8),
                      "Native Back should dismiss the missing workout fallback")
        let activityRoot = app.scrollViews[AXID.activityRootScroll].firstMatch
        XCTAssertTrue(activityRoot.waitForExistence(timeout: 8), "Native Back should return to Activity")
        XCTAssertTrue(activityRoot.isHittable, "Activity should be frontmost and interactive")

        let replay = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in scroll.exists || !activityRoot.exists || !activityRoot.isHittable },
            object: nil
        )
        replay.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [replay], timeout: 3), .completed,
                       "The fallback must remain dismissed and Activity interactive while navigation settles")
    }

    private func t14RevealMissingWorkoutRouteRow(_ row: XCUIElement) -> Bool {
        let hub = app.collectionViews[AXID.notificationHubScreen].firstMatch
        guard hub.exists else { return false }
        let window = app.windows.firstMatch.frame
        let navigationBar = app.navigationBars["Notifications"].firstMatch
        let tabBar = app.tabBars.firstMatch
        let top = max(window.minY, navigationBar.exists ? navigationBar.frame.maxY : window.minY)
        let bottom = tabBar.exists && tabBar.isHittable && tabBar.frame.minY > window.midY
            ? min(window.maxY, tabBar.frame.minY) : window.maxY
        let viewport = hub.frame.intersection(CGRect(x: window.minX, y: top,
                                                     width: window.width, height: max(0, bottom - top)))
            .insetBy(dx: 0, dy: 4)
        guard !viewport.isNull && viewport.height > 80 && hub.frame.height > 0 else { return false }

        for attempt in 0..<10 {
            if row.exists {
                let frame = row.frame
                if viewport.contains(frame) && row.isHittable { return true }
            }
            if attempt == 9 { break }
            let startY = viewport.minY + viewport.height * 0.75
            let endY = viewport.minY + viewport.height * 0.35
            let start = hub.coordinate(withNormalizedOffset:
                CGVector(dx: 0.5, dy: (startY - hub.frame.minY) / hub.frame.height))
            let end = hub.coordinate(withNormalizedOffset:
                CGVector(dx: 0.5, dy: (endY - hub.frame.minY) / hub.frame.height))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        return false
    }

    private enum T14FallbackTextPosition { case whole, start, end }

    private func t14FallbackViewport(for scroll: XCUIElement, horizontalInset: CGFloat = 4) -> CGRect {
        let scrollFrame = scroll.frame
        var viewport = scrollFrame.intersection(app.windows.firstMatch.frame).insetBy(dx: horizontalInset, dy: 0)
        let navigationBar = app.navigationBars["Notification"].firstMatch
        if navigationBar.exists && navigationBar.frame.maxY < scrollFrame.midY {
            let bottom = viewport.maxY
            viewport.origin.y = max(viewport.minY, navigationBar.frame.maxY + 4)
            viewport.size.height = max(0, bottom - viewport.minY)
        }
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists && tabBar.isHittable && tabBar.frame.minY > scrollFrame.midY {
            viewport.size.height = max(0, min(viewport.maxY, tabBar.frame.minY - 4) - viewport.minY)
        }
        return viewport
    }

    private func t14RevealFallbackText(_ element: XCUIElement, in scroll: XCUIElement,
                                       position: T14FallbackTextPosition, horizontalInset: CGFloat = 4) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let viewport = t14FallbackViewport(for: scroll, horizontalInset: horizontalInset)
            XCTAssertGreaterThan(viewport.height, 72, "The fallback should have a readable viewport")
            let frame = element.frame
            let horizontalFit = frame.minX >= viewport.minX && frame.maxX <= viewport.maxX
            let reached: Bool
            switch position {
            case .whole:
                reached = viewport.contains(frame) && element.isHittable
            case .start:
                reached = horizontalFit && frame.minY >= viewport.minY
                    && frame.intersection(viewport).height >= 24
            case .end:
                reached = horizontalFit && frame.maxY <= viewport.maxY
                    && frame.intersection(viewport).height >= 24
            }
            if reached { return }

            let moveUp: Bool
            switch position {
            case .whole, .start: moveUp = frame.minY >= viewport.midY
            case .end: moveUp = frame.maxY > viewport.maxY
            }
            let startY = moveUp ? viewport.maxY - 24 : viewport.minY + 24
            let endY = moveUp ? viewport.minY + 36 : viewport.maxY - 36
            let start = scroll.coordinate(withNormalizedOffset:
                CGVector(dx: 0.5, dy: (startY - scroll.frame.minY) / scroll.frame.height))
            let end = scroll.coordinate(withNormalizedOffset:
                CGVector(dx: 0.5, dy: (endY - scroll.frame.minY) / scroll.frame.height))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        let viewport = t14FallbackViewport(for: scroll, horizontalInset: horizontalInset)
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX, "Text should fit horizontally")
        XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX, "Text should fit horizontally")
        switch position {
        case .whole:
            XCTAssertTrue(viewport.contains(frame) && element.isHittable,
                          "The whole title or ID should be readable")
        case .start:
            XCTAssertGreaterThanOrEqual(frame.minY, viewport.minY)
            XCTAssertGreaterThanOrEqual(frame.intersection(viewport).height, 24)
        case .end:
            XCTAssertLessThanOrEqual(frame.maxY, viewport.maxY)
            XCTAssertGreaterThanOrEqual(frame.intersection(viewport).height, 24)
        }
    }

    // MARK: - Helpers

    private func openTrainingReadinessDetail() {
        ensureActivityRoot()
        let readinessHero = waitForElement(AXID.activityHeroReadiness, timeout: 15)
        readinessHero.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityTrainingReadinessDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Training Readiness detail should open from the Activity hero"
        )
    }

    private func openTrainingVolumeDetailSurface(maximumAccessibilitySize: Bool = false) {
        if maximumAccessibilitySize {
            ensureActivityRoot()
            let contentID = "activity-section-volume-content"
            // AX puts this section several screens below the initial viewport. The
            // Existing summary navigation reveals visible content, then the header.
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(contentID, maxSwipes: 32))
            let card = app.buttons[contentID].firstMatch
            let activityScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
            let viewport = activityScroll.frame.intersection(app.windows.firstMatch.frame)
            XCTAssertTrue(card.exists && card.isHittable)
            XCTAssertTrue(viewport.intersects(card.frame))
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(
                AXID.activitySectionVolume, maxSwipes: 8, direction: .down
            ))
            app.buttons[AXID.activitySectionVolume].firstMatch.auditTap()
            XCTAssertTrue(app.descendants(matching: .any)[AXID.activityTrainingVolumeDetailScreen]
                .firstMatch.waitForExistence(timeout: 10))
        } else {
            openActivityDetail(
                sectionIdentifier: AXID.activitySectionVolume,
                destinationIdentifier: AXID.activityTrainingVolumeDetailScreen,
                maxSwipes: 8
            )
        }
    }

    private func openActivityDetail(
        sectionIdentifier: String,
        destinationIdentifier: String,
        maxSwipes: Int
    ) {
        ensureActivityRoot()
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(sectionIdentifier, maxSwipes: maxSwipes),
            "\(sectionIdentifier) should be reachable before opening detail"
        )
        let section = waitForElement(sectionIdentifier, timeout: 8)
        section.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[destinationIdentifier].firstMatch.waitForExistence(timeout: 10),
            "\(destinationIdentifier) should open from the Activity surface"
        )
    }

    private func ensureActivityRoot() {
        let activityAddButton = app.descendants(matching: .any)[AXID.activityToolbarAdd].firstMatch
        if !activityAddButton.waitForExistence(timeout: 3) {
            let backButton = app.navigationBars.buttons["BackButton"].firstMatch
            if backButton.waitForExistence(timeout: 2) {
                backButton.auditTap()
            }
        }

        let hero = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Activity hero should exist")
        XCTAssertTrue(activityAddButton.waitForExistence(timeout: 5), "Activity add button should exist")
    }

    private func openQuickStartPicker() {
        ensureActivityRoot()
        let addButton = app.descendants(matching: .any)[AXID.activityToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Activity add button should exist")
        addButton.auditTap()

        let picker = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8), "Quick Start picker should appear")
    }

    private func openExerciseViewFromRecentWorkouts(maxSwipes: Int = 10) {
        ensureActivityRoot()
        let seeAllButton = app.buttons[AXID.activityRecentSeeAll].firstMatch
        let exerciseScreen = app.descendants(matching: .any)[AXID.exerciseViewScreen].firstMatch
        let exerciseToolbarAdd = app.descendants(matching: .any)[AXID.exerciseToolbarAdd].firstMatch
        let rootScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
        XCTAssertTrue(rootScroll.waitForExistence(timeout: 5), "Activity root scroll should exist")
        for _ in 0..<2 {
            for _ in 0..<max(24, maxSwipes) where !seeAllButton.isHittable {
                rootScroll.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(seeAllButton.isHittable,
                          "Recent workouts See All should be reachable and tappable")
            XCTAssertTrue(seeAllButton.waitForExistence(timeout: 5), "Recent workouts See All should exist")
            // A partially visible row can be reported as hittable while its
            // center is under the collapsed navigation bar. Reveal the whole
            // action in the interior of the scroll viewport before tapping.
            for _ in 0..<2 {
                for _ in 0..<8 {
                    let viewport = rootScroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 80)
                    if seeAllButton.isHittable && viewport.contains(seeAllButton.frame) { break }
                    if seeAllButton.frame.midY < viewport.midY { rootScroll.swipeDown(velocity: .slow) }
                    else { rootScroll.swipeUp(velocity: .slow) }
                }
                let viewport = rootScroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 80)
                guard seeAllButton.isHittable && viewport.contains(seeAllButton.frame) else { continue }
                seeAllButton.auditTap()

                if exerciseScreen.waitForExistence(timeout: 10) ||
                    exerciseToolbarAdd.waitForExistence(timeout: 10) {
                    return
                }
            }
        }

        XCTFail("Exercise screen should appear")
    }

    private func openExerciseSingleExercisePicker() {
        openExerciseViewFromRecentWorkouts()

        let addMenu = app.descendants(matching: .any)[AXID.exerciseToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Exercise add menu should exist")
        addMenu.auditTap()

        let singleExerciseOption = app.descendants(matching: .any)[AXID.exerciseMenuSingle].firstMatch
        XCTAssertTrue(singleExerciseOption.waitForExistence(timeout: 5), "Single Exercise menu item should exist")
        singleExerciseOption.auditTap()

        let picker = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8), "Exercise quick start picker should appear")
    }

    private func startQuickStartExerciseFromDetail(search: String, exerciseID: String) {
        XCTAssertTrue(app.fillTextInput(AXID.pickerSearchField, with: search), "Picker search should accept \(search)")
        dismissSearchKeyboardIfPresent()

        let detailButton = app.descendants(matching: .any)[AXID.pickerExerciseDetailButton(exerciseID)].firstMatch
        XCTAssertTrue(
            app.scrollToHittablePickerElementIfNeeded(AXID.pickerExerciseDetailButton(exerciseID), maxSwipes: 8),
            "Quick start detail button should be reachable for \(exerciseID)"
        )
        XCTAssertTrue(detailButton.waitForExistence(timeout: 8), "Quick start detail button should exist for \(exerciseID)")
        detailButton.auditTap()

        let detailScreen = app.descendants(matching: .any)[AXID.exerciseDetailScreen].firstMatch
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 8), "Exercise detail sheet should appear")

        let detailStartButton = app.descendants(matching: .any)[AXID.exerciseDetailStart].firstMatch
        XCTAssertTrue(detailStartButton.waitForExistence(timeout: 5), "Exercise detail start button should exist")
        detailStartButton.auditTap()

        let exerciseStartScreen = app.descendants(matching: .any)[AXID.exerciseStartScreen].firstMatch
        XCTAssertTrue(exerciseStartScreen.waitForExistence(timeout: 10), "Exercise start sheet should appear")

        let startButton = app.buttons[AXID.exerciseStartButton].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Exercise start button should exist")
        startButton.auditTap()
    }

    private func dismissSearchKeyboardIfPresent() {
        let pickerDone = app.buttons["picker-search-done"].firstMatch
        if pickerDone.exists && pickerDone.isHittable {
            pickerDone.auditTap()
            return
        }

        if app.textFields[AXID.pickerSearchField].firstMatch.exists {
            XCTAssertTrue(pickerDone.waitForExistence(timeout: 3), "Quick-start search should expose its Done action")
            XCTAssertTrue(pickerDone.isHittable, "Quick-start search Done should be reachable")
            pickerDone.auditTap()
            return
        }

        // Full-mode searchable uses the system keyboard rather than the inline action.
        let keyboard = app.keyboards.firstMatch
        guard keyboard.waitForExistence(timeout: 1) else { return }

        let exactCandidates = [
            keyboard.buttons["Search"],
            keyboard.buttons["search"]
        ]

        if let button = exactCandidates.first(where: { $0.exists && $0.isHittable }) {
            button.auditTap()
            return
        }

        let searchButton = keyboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'search'")).firstMatch
        if searchButton.exists && searchButton.isHittable {
            searchButton.auditTap()
            return
        }

        // Duo can expose an offscreen Search key. The picker explicitly uses
        // scrollDismissesKeyboard(.immediately), so use its identified list.
        let pickerList = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        XCTAssertTrue(pickerList.waitForExistence(timeout: 3), "Picker list should be available to dismiss the keyboard")
        pickerList.swipeUp()
        let keyboardDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: keyboard
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [keyboardDismissed], timeout: 3),
            .completed,
            "Scrolling the picker should dismiss the offscreen search keyboard"
        )
    }

    private func openTemplateList() {
        openExerciseViewFromRecentWorkouts()
        let templatesButton = app.descendants(matching: .any)[AXID.exerciseToolbarTemplates].firstMatch
        XCTAssertTrue(templatesButton.waitForExistence(timeout: 5), "Templates toolbar button should exist")
        templatesButton.auditTap()

        let templateScreen = app.descendants(matching: .any)[AXID.workoutTemplateListScreen].firstMatch
        XCTAssertTrue(templateScreen.waitForExistence(timeout: 8), "Template list screen should appear")
    }

    private func openSeededSingleTemplateEditor() {
        let row = app.buttons[AXID.workoutTemplateRow(Fixture.singleTemplate)].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Seeded single template should exist")
        if !row.isHittable {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.workoutTemplateRow(Fixture.singleTemplate), maxSwipes: 8))
        }
        row.swipeRight()
        let edit = app.buttons[AXID.workoutTemplateEdit(Fixture.singleTemplate)].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5) && edit.isHittable, "Seeded template edit should be reachable")
        edit.auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch.waitForExistence(timeout: 8),
            "Seeded template editor should open"
        )
    }

    private func captureFunctionalCheckpoint(_ name: String) {
        guard !VisualAudit.isEnabled else { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollToWorkoutControl(
        _ identifier: String, maxSwipes: Int = 8, mustFitInViewport: Bool = false
    ) -> Bool {
        let control = app.descendants(matching: .any)[identifier].firstMatch
        let container = app.scrollViews["workout-session-controls"].firstMatch
        guard container.waitForExistence(timeout: 5) else { return false }
        for _ in 0..<maxSwipes {
            let containerFrame = container.frame
            let viewport = containerFrame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 8)
            let controlExists = control.exists
            let controlFrame = controlExists ? control.frame : .zero
            let fits = mustFitInViewport ? viewport.contains(controlFrame)
                : viewport.contains(CGPoint(x: controlFrame.midX, y: controlFrame.midY))
            // Query hit testing only once geometry places the target on screen.
            if controlExists && fits && control.isHittable { return true }
            if controlExists && containerFrame.height > 0 {
                let delta = controlFrame.midY - viewport.midY
                let travel = min(max(abs(delta), 20), containerFrame.height * 0.25) / containerFrame.height
                let startY: CGFloat = delta < 0 ? 0.3 : 0.7
                let endY = startY + (delta < 0 ? travel : -travel)
                container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                    .press(forDuration: 0.05, thenDragTo: container.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: endY)
                    ), withVelocity: .slow, thenHoldForDuration: 0.2)
            } else if controlExists && controlFrame.midY < containerFrame.midY {
                container.swipeDown(velocity: .slow)
            } else {
                container.swipeUp(velocity: .slow)
            }
        }
        let viewport = container.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 8)
        return control.exists && control.isHittable
            && (mustFitInViewport ? viewport.contains(control.frame)
                : viewport.contains(CGPoint(x: control.frame.midX, y: control.frame.midY)))
    }

    private func assertActiveWorkoutInputsAfterFold(weight: String, reps: String) {
        let session = app.descendants(matching: .any)[AXID.workoutSessionScreen].firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 10), "The active workout must survive each fold transition")
        let controls = app.scrollViews["workout-session-controls"].firstMatch
        XCTAssertTrue(controls.waitForExistence(timeout: 5), "Active workout controls must remain available")
        for (field, expected) in [("kg", weight), ("reps", reps)] {
            let identifier = AXID.workoutSessionField(field)
            VisualAudit.capture("Workout \(field) viewport before bounded input reveal")
            let revealed = scrollToWorkoutControl(identifier, mustFitInViewport: true)
            if !VisualAudit.isEnabled {
                let image = XCTAttachment(screenshot: app.screenshot())
                image.name = "Workout \(field) input after bounded reveal"
                image.lifetime = .keepAlways
                add(image)
                let hierarchy = XCTAttachment(string: app.debugDescription)
                hierarchy.name = "Workout \(field) viewport hierarchy"
                hierarchy.lifetime = .keepAlways
                add(hierarchy)
            }
            XCTAssertTrue(revealed,
                          "The full \(field) input must remain visible after folding")
            XCTAssertEqual(app.textFields[identifier].firstMatch.value as? String, expected,
                           "\(field) input must survive each fold transition")
        }
        let completeSet = app.buttons[AXID.workoutSessionCompleteSet].firstMatch
        XCTAssertTrue(completeSet.waitForExistence(timeout: 5) && completeSet.isEnabled,
                      "The current set must stay actionable after folding")
        let done = app.buttons[AXID.workoutSessionDone].firstMatch
        for _ in 0..<6 where !done.exists { controls.swipeDown() }
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Session Done should remain available")
        XCTAssertFalse(done.isEnabled, "Folding must not complete an unfinished set")
    }

    private func assertCompletedSetSummaryDuringRest(weight: String, reps: String) {
        XCTAssertTrue(app.descendants(matching: .any)[AXID.workoutSessionScreen].firstMatch.waitForExistence(timeout: 5),
                      "The workout must remain active during rest")
        let summary = app.descendants(matching: .any)["workout-session-completed-set-summary"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Completed first set should remain visible during rest")
        XCTAssertTrue(summary.label.contains(weight) && summary.label.contains(reps),
                      "Completed summary must retain the edited weight and reps (actual: \(summary.label))")
    }

    private func restCountdownSeconds() throws -> Int {
        let countdown = app.staticTexts["workout-session-rest-countdown"].firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 5), "Rest countdown should remain visible")
        let components = countdown.label.split(separator: ":")
        guard components.count == 2 else {
            XCTFail("Rest countdown should expose m:ss (actual: \(countdown.label))")
            return 0
        }
        let minutes = try XCTUnwrap(Int(components[0]), "Rest countdown minutes should be numeric")
        let seconds = try XCTUnwrap(Int(components[1]), "Rest countdown seconds should be numeric")
        XCTAssertTrue((0..<60).contains(seconds), "Rest countdown seconds should use a minute-second clock")
        return minutes * 60 + seconds
    }

    private func addCompoundExercise(_ exerciseID: String) {
        let setupScreen = app.descendants(matching: .any)[AXID.compoundWorkoutSetupScreen].firstMatch
        XCTAssertTrue(setupScreen.waitForExistence(timeout: 5), "Compound setup screen should exist")

        let addExercise = app.descendants(matching: .any)[AXID.compoundWorkoutSetupAddExercise].firstMatch
        XCTAssertTrue(addExercise.waitForExistence(timeout: 5), "Add exercise button should exist in setup")
        XCTAssertTrue(
            openCompoundPicker(using: addExercise, in: setupScreen),
            "Add exercise button should be reachable in compound setup"
        )
        VisualAudit.capture("Compound exercise picker")

        let pickerRow = app.descendants(matching: .any)[AXID.pickerExerciseRow(exerciseID)].firstMatch
        XCTAssertTrue(
            app.scrollToHittablePickerElementIfNeeded(AXID.pickerExerciseRow(exerciseID), maxSwipes: 8),
            "Compound picker row should be reachable for \(exerciseID)"
        )
        XCTAssertTrue(pickerRow.waitForExistence(timeout: 8), "Compound picker row should exist for \(exerciseID)")
        pickerRow.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.compoundWorkoutSetupScreen].firstMatch.waitForExistence(timeout: 8),
            "Compound setup should return after picker selection"
        )
    }

    private func openNotificationHub() {
        navigateToDashboard()
        let dashboardHero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(dashboardHero.waitForExistence(timeout: 12), "Dashboard hero should appear before opening notifications")

        let notificationsButton = app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(notificationsButton.waitForExistence(timeout: 5), "Notifications button should exist on the dashboard")
        XCTAssertTrue(waitForNotificationButton(notificationsButton), "Notifications button should be tappable")
        notificationsButton.auditTap()

        let hub = app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
        XCTAssertTrue(hub.waitForExistence(timeout: 8), "Notification hub should appear")
    }

    private func tapBackButton() {
        // Duo exposes its system rail back control outside navigationBars.
        let railBack = app.buttons["BackButton"].firstMatch
        if railBack.exists && railBack.isHittable {
            railBack.auditTap()
            return
        }
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should exist")
        backButton.auditTap()
    }

    private func openCompoundPicker(using button: XCUIElement, in container: XCUIElement, maxSwipes: Int = 6) -> Bool {
        let picker = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch

        if button.isHittable {
            button.auditTap()
            return picker.waitForExistence(timeout: 5)
        }

        for _ in 0..<maxSwipes {
            if button.exists {
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).auditTap()
                if picker.waitForExistence(timeout: 2) {
                    return true
                }
            }
            container.swipeUp()
        }

        for _ in 0..<maxSwipes {
            if button.exists {
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).auditTap()
                if picker.waitForExistence(timeout: 2) {
                    return true
                }
            }
            container.swipeDown()
        }

        return false
    }

    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForEither(_ first: XCUIElement, _ second: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if first.exists || second.exists {
                return true
            }

            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        return first.exists || second.exists
    }

    private func waitForNotificationButton(_ button: XCUIElement, timeout: TimeInterval = 12) -> Bool {
        let briefingScreen = app.descendants(matching: .any)[AXID.dashboardMorningBriefingScreen].firstMatch
        let dismissButton = app.descendants(matching: .any)[AXID.dashboardMorningBriefingDismiss].firstMatch
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if button.isHittable { return true }
            if briefingScreen.exists && dismissButton.isHittable {
                dismissButton.tap()
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        return button.isHittable
    }

}
