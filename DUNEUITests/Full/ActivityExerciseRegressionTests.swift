@preconcurrency import XCTest

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
        try verifyWorkoutInsightsReturnsToWorkout()
    }

    func testWorkoutInsightsReturnsToInteractiveWorkoutAtMaximumAccessibilityTextSize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        try verifyWorkoutInsightsReturnsToWorkout(useQuickStart: true)
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

    private func verifyWorkoutInsightsReturnsToWorkout(useQuickStart: Bool = false) throws {
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
            let metricPicker = app.buttons["weeklystats-chart-metric-picker"].firstMatch
            for _ in 0..<8 where !(metricPicker.exists && metricPicker.isHittable) {
                app.scrollViews.firstMatch.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(metricPicker.exists && metricPicker.isHittable,
                          "The chart metric menu must be reachable at maximum accessibility size")
            let statsScroll = app.scrollViews.firstMatch
            statsScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
                .press(forDuration: 0.05, thenDragTo: statsScroll.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)
                ))
            XCTAssertTrue(metricPicker.isHittable)
            XCTAssertTrue(app.staticTexts["weeklystats-chart-heading"].firstMatch.isHittable,
                          "The chart title must remain visible above its metric menu")
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
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.activitySectionVolume, maxSwipes: 24))
        let card = app.buttons[AXID.activitySectionVolume].firstMatch
        let viewport = app.scrollViews[AXID.activityRootScroll].firstMatch.frame
            .intersection(app.windows.firstMatch.frame)
        XCTAssertTrue(card.exists && card.isHittable)
        XCTAssertTrue(viewport.contains(CGPoint(x: card.frame.midX, y: card.frame.midY)))
        VisualAudit.capture("Maximum AX training volume summary labels")
        card.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityTrainingVolumeDetailScreen]
            .firstMatch.waitForExistence(timeout: 10))
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

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionWeeklyStats, maxSwipes: 4))
        waitForElement(AXID.activitySectionWeeklyStats, timeout: 5).auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityWeeklyStatsDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Weekly Stats detail should appear"
        )

        tapBackButton()
        ensureActivityRoot()

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionVolume, maxSwipes: 8))
        waitForElement(AXID.activitySectionVolume, timeout: 5).auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityTrainingVolumeDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Training Volume detail should open"
        )

        let exerciseTypeRow = app.descendants(matching: .any)[AXID.activityTrainingVolumeRow("manual-strength")].firstMatch
        XCTAssertTrue(exerciseTypeRow.waitForExistence(timeout: 8), "Seeded manual strength exercise type row should exist")
    }

    func testActivitySecondaryDetailRoutesOpenExpectedScreens() throws {
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionPR, maxSwipes: 10))
        waitForElement(AXID.activitySectionPR, timeout: 5).auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityPersonalRecordsDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Personal Records should open"
        )

        tapBackButton()
        ensureActivityRoot()

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionConsistency, maxSwipes: 10))
        waitForElement(AXID.activitySectionConsistency, timeout: 5).auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityConsistencyDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Consistency detail should open"
        )
    }

    func testActivityExerciseMixRouteOpensExpectedScreen() throws {
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionExerciseMix, maxSwipes: 10))
        waitForElement(AXID.activitySectionExerciseMix, timeout: 5).auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityExerciseMixDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Exercise Mix detail should open"
        )
    }

    func testExerciseTypeDetailShowsTrendSurface() throws {
        openTrainingVolumeDetailSurface()

        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.activityTrainingVolumeTypeList, maxSwipes: 10),
            "Exercise type list should be reachable in Training Volume detail"
        )
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.activityTrainingVolumeRow(Fixture.manualStrengthTypeKey), maxSwipes: 10),
            "Manual strength row should be reachable in Training Volume detail"
        )
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

        tapSegment(in: AXID.activityExerciseTypePeriodPicker, index: 1, timeout: 10)

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityExerciseTypeTrendChart].firstMatch.waitForExistence(timeout: 15),
            "Exercise type detail should keep the trend chart visible after period switching"
        )
    }

    func testPersonalRecordsDetailShowsTimelineRewardsAndHistory() throws {
        if VisualAudit.isEnabled {
            var configuration = launchConfiguration
            configuration.additionalArguments += [
                "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
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
            for (identifier, checkpoint) in [
                (AXID.activityPersonalRecordsTimelineChart, "timeline endpoint and axes"),
                (AXID.activityPersonalRecordsRewardProgress, "reward progress"),
                (AXID.activityPersonalRecordsAchievementHistory, "achievement history")
            ] {
                let section = app.descendants(matching: .any)[identifier].firstMatch
                for _ in 0..<16 {
                    let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 8)
                    if section.exists && viewport.contains(CGPoint(x: section.frame.midX, y: section.frame.midY)) { break }
                    if section.exists && section.frame.midY < viewport.midY { scroll.swipeDown(velocity: .slow) }
                    else { scroll.swipeUp(velocity: .slow) }
                }
                let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 8, dy: 8)
                XCTAssertTrue(section.exists && viewport.contains(CGPoint(x: section.frame.midX, y: section.frame.midY)),
                              "Personal Records \(checkpoint) should reach the visible viewport")
                VisualAudit.capture("Personal Records maximum AX \(checkpoint) viewport")
            }
        }
    }

    func testConsistencyDetailShowsCalendarAndHistorySections() throws {
        openActivityDetail(
            sectionIdentifier: AXID.activitySectionConsistency,
            destinationIdentifier: AXID.activityConsistencyDetailScreen,
            maxSwipes: 10
        )

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityConsistencyCalendar].firstMatch.waitForExistence(timeout: 15),
            "Consistency detail should show the calendar heatmap"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityConsistencyHistory].firstMatch.waitForExistence(timeout: 15),
            "Consistency detail should show the streak history"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[AXID.activityConsistencyEmptyState].firstMatch.exists,
            "Seeded consistency detail should not fall back to the empty state"
        )
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
        if VisualAudit.isEnabled {
            var configuration = launchConfiguration
            configuration.additionalArguments += [
                "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ]
            launchApp(with: configuration)
            XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8))
        }
        openExerciseSingleExercisePicker()
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

    func testNotificationMissingWorkoutRouteShowsFallback() throws {
        openNotificationHub()

        let missingRouteRow = app.buttons[AXID.notificationWorkoutRow(Fixture.notificationMissingRouteID)].firstMatch
        XCTAssertTrue(missingRouteRow.waitForExistence(timeout: 8), "Missing route notification should exist")
        missingRouteRow.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.notificationTargetNotFoundScreen].firstMatch.waitForExistence(timeout: 10),
            "Missing workout route should open fallback screen"
        )
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

    private func openTrainingVolumeDetailSurface() {
        openActivityDetail(
            sectionIdentifier: AXID.activitySectionVolume,
            destinationIdentifier: AXID.activityTrainingVolumeDetailScreen,
            maxSwipes: 8
        )
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
        for _ in 0..<2 {
            XCTAssertTrue(
                app.scrollToHittableElementIfNeeded(AXID.activityRecentSeeAll, maxSwipes: maxSwipes),
                "Recent workouts See All should be reachable and tappable"
            )
            XCTAssertTrue(seeAllButton.waitForExistence(timeout: 5), "Recent workouts See All should exist")
            // A partially visible row can be reported as hittable while its
            // center is under the collapsed navigation bar. Reveal the whole
            // action in the interior of the scroll viewport before tapping.
            let rootScroll = app.scrollViews[AXID.activityRootScroll].firstMatch
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
