@preconcurrency import XCTest

@MainActor
final class ActivityExerciseRegressionTests: ActivityExerciseSeededUITestBaseCase {
    private enum Fixture {
        static let benchPressID = "barbell-bench-press"
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
    }

    func testActivityDetailRoutesOpenExpectedScreens() throws {
        let readinessHero = waitForElement(AXID.activityHeroReadiness, timeout: 15)
        readinessHero.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityTrainingReadinessDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Training Readiness detail should appear"
        )

        tapBackButton()
        ensureActivityRoot()

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionMuscleMap, maxSwipes: 4))
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.activityMuscleMapDetailLink, maxSwipes: 4),
            "Muscle Map detail link should be reachable"
        )
        waitForElement(AXID.activityMuscleMapDetailLink, timeout: 5).tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityMuscleMapDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Muscle Map detail should open"
        )

        tapBackButton()
        ensureActivityRoot()

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionWeeklyStats, maxSwipes: 4))
        waitForElement(AXID.activitySectionWeeklyStats, timeout: 5).tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityWeeklyStatsDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Weekly Stats detail should appear"
        )

        tapBackButton()
        ensureActivityRoot()

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionVolume, maxSwipes: 8))
        waitForElement(AXID.activitySectionVolume, timeout: 5).tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityTrainingVolumeDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Training Volume detail should open"
        )

        let exerciseTypeRow = app.descendants(matching: .any)[AXID.activityTrainingVolumeRow("manual-strength")].firstMatch
        XCTAssertTrue(exerciseTypeRow.waitForExistence(timeout: 8), "Seeded manual strength exercise type row should exist")
    }

    func testActivitySecondaryDetailRoutesOpenExpectedScreens() throws {
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionPR, maxSwipes: 10))
        waitForElement(AXID.activitySectionPR, timeout: 5).tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityPersonalRecordsDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Personal Records should open"
        )

        tapBackButton()
        ensureActivityRoot()

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionConsistency, maxSwipes: 10))
        waitForElement(AXID.activitySectionConsistency, timeout: 5).tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityConsistencyDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Consistency detail should open"
        )
    }

    func testActivityExerciseMixRouteOpensExpectedScreen() throws {
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activitySectionExerciseMix, maxSwipes: 10))
        waitForElement(AXID.activitySectionExerciseMix, timeout: 5).tap()
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
        row.tap()

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
        openActivityDetail(
            sectionIdentifier: AXID.activitySectionPR,
            destinationIdentifier: AXID.activityPersonalRecordsDetailScreen,
            maxSwipes: 10
        )

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityPersonalRecordsMetricPicker].firstMatch.waitForExistence(timeout: 15),
            "Personal Records detail should expose the metric picker"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityPersonalRecordsTimelineChart].firstMatch.waitForExistence(timeout: 15),
            "Personal Records detail should render the timeline chart"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityPersonalRecordsRewardSummary].firstMatch.waitForExistence(timeout: 15),
            "Personal Records detail should show the reward summary"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.activityPersonalRecordsAchievementHistory].firstMatch.waitForExistence(timeout: 15),
            "Personal Records detail should show the achievement history"
        )
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
        benchPressRow.tap()

        let historyLink = app.descendants(matching: .any)[AXID.exerciseSessionViewHistory].firstMatch
        XCTAssertTrue(historyLink.waitForExistence(timeout: 10), "View history link should exist")
        historyLink.tap()

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
        detailButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseDetailScreen].firstMatch.waitForExistence(timeout: 8),
            "Exercise detail sheet should appear"
        )

        let closeButton = app.descendants(matching: .any)[AXID.exerciseDetailClose].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Detail close button should exist")
        closeButton.tap()

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
        recommendationCard.tap()

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
        builderEntry.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch.waitForExistence(timeout: 8),
            "Template form should open from Activity AI builder entry"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateFormAIPrompt].firstMatch.waitForExistence(timeout: 5),
            "Template form should expose the AI prompt field in create mode"
        )
    }

    func testManualWorkoutSessionSavesAndDismissesCompletionSheet() throws {
        openExerciseSingleExercisePicker()
        startQuickStartExerciseFromDetail(search: "Bench Press", exerciseID: Fixture.benchPressID)

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.workoutSessionScreen].firstMatch.waitForExistence(timeout: 10),
            "Workout session screen should open"
        )

        let weightIncrease = app.buttons["+2.5"].firstMatch
        XCTAssertTrue(weightIncrease.waitForExistence(timeout: 5), "Weight increment button should exist")
        weightIncrease.tap()

        let repsIncrease = app.buttons["+1"].firstMatch
        XCTAssertTrue(repsIncrease.waitForExistence(timeout: 5), "Reps increment button should exist")
        repsIncrease.tap()

        let completeSetButton = app.buttons[AXID.workoutSessionCompleteSet].firstMatch
        XCTAssertTrue(completeSetButton.waitForExistence(timeout: 5), "Complete Set button should exist")
        completeSetButton.tap()

        let doneButton = app.descendants(matching: .any)[AXID.workoutSessionDone].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "Done button should exist")
        XCTAssertTrue(doneButton.isEnabled, "Done button should enable after one completed set")
        doneButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.workoutCompletionSheet].firstMatch.waitForExistence(timeout: 10),
            "Workout completion sheet should appear"
        )

        let completionDoneButton = app.descendants(matching: .any)[AXID.workoutCompletionDone].firstMatch
        XCTAssertTrue(completionDoneButton.waitForExistence(timeout: 5), "Workout completion done button should exist")
        completionDoneButton.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseViewScreen].firstMatch.waitForExistence(timeout: 10),
            "Completion sheet dismissal should return to Exercise root"
        )
    }

    func testTemplateListSupportsCreateEditAndTemplateStart() throws {
        openTemplateList()

        let addButton = app.descendants(matching: .any)[AXID.workoutTemplateListAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Template add button should exist")
        addButton.tap()

        let templateForm = app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch
        XCTAssertTrue(templateForm.waitForExistence(timeout: 8), "Template form should appear")

        let saveButton = app.buttons[AXID.templateFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Template save button should exist")
        XCTAssertFalse(saveButton.isEnabled, "Template save should be disabled without name and entries")

        app.descendants(matching: .any)[AXID.templateFormAddExercise].firstMatch.tap()

        let createCustomButton = app.descendants(matching: .any)[AXID.pickerCreateCustomButton].firstMatch
        XCTAssertTrue(createCustomButton.waitForExistence(timeout: 8), "Create custom button should exist in full picker")
        createCustomButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.createCustomExerciseScreen].firstMatch.waitForExistence(timeout: 8),
            "Create custom exercise screen should appear"
        )
        XCTAssertTrue(
            app.fillTextInput(AXID.createCustomExerciseName, with: Fixture.customExercise),
            "Custom exercise name should be editable"
        )
        let shouldersChip = app.buttons[AXID.createCustomExerciseMuscle("shoulders")].firstMatch
        XCTAssertTrue(shouldersChip.waitForExistence(timeout: 5), "Shoulders chip should exist")
        shouldersChip.tap()
        app.descendants(matching: .any)[AXID.createCustomExerciseCreate].firstMatch.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch.waitForExistence(timeout: 8),
            "Template form should return after custom exercise creation"
        )
        XCTAssertTrue(app.fillTextInput(AXID.templateFormName, with: Fixture.createdTemplate), "Template name should be editable")
        XCTAssertTrue(saveButton.isEnabled, "Template save should enable after required inputs")
        saveButton.tap()

        let createdTemplateRow = app.buttons[AXID.workoutTemplateRow(Fixture.createdTemplate)].firstMatch
        XCTAssertTrue(createdTemplateRow.waitForExistence(timeout: 8), "Created template should appear in list")

        let seedCell = app.buttons[AXID.workoutTemplateRow(Fixture.singleTemplate)].firstMatch
        XCTAssertTrue(seedCell.waitForExistence(timeout: 8), "Seeded single template should exist")
        seedCell.swipeRight()

        let editButton = app.buttons[AXID.workoutTemplateEdit(Fixture.singleTemplate)].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit swipe action should appear")
        editButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch.waitForExistence(timeout: 8),
            "Edit template form should appear"
        )
        XCTAssertTrue(app.fillTextInput(AXID.templateFormName, with: Fixture.updatedTemplate), "Seeded template name should be editable")
        app.buttons[AXID.templateFormSave].firstMatch.tap()

        XCTAssertTrue(app.buttons[AXID.workoutTemplateRow(Fixture.updatedTemplate)].firstMatch.waitForExistence(timeout: 8), "Updated template should appear")

        let circuitTemplate = app.buttons[AXID.workoutTemplateRow(Fixture.circuitTemplate)].firstMatch
        XCTAssertTrue(circuitTemplate.waitForExistence(timeout: 8), "Seeded multi template should exist")
        circuitTemplate.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateWorkoutContainerScreen].firstMatch.waitForExistence(timeout: 10),
            "Template workout container should open for multi-exercise template"
        )
    }

    func testCompoundWorkoutSetupStartsWorkout() throws {
        openExerciseViewFromRecentWorkouts()

        let addMenu = app.descendants(matching: .any)[AXID.exerciseToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Exercise add menu should exist")
        addMenu.tap()

        let compoundOption = app.descendants(matching: .any)[AXID.exerciseMenuCompound].firstMatch
        XCTAssertTrue(compoundOption.waitForExistence(timeout: 5), "Superset / Circuit menu item should exist")
        compoundOption.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.compoundWorkoutSetupScreen].firstMatch.waitForExistence(timeout: 8),
            "Compound workout setup should appear"
        )

        addCompoundExercise(Fixture.benchPressID)
        addCompoundExercise("barbell-squat")

        let selectionCount = app.descendants(matching: .any)[AXID.compoundWorkoutSetupSelectionCount].firstMatch
        XCTAssertTrue(selectionCount.waitForExistence(timeout: 5), "Compound setup selection count should exist")
        XCTAssertEqual(selectionCount.label, "Exercises (2)", "Compound setup should reflect both selected exercises")

        let startButtons = app.descendants(matching: .any)
            .matching(identifier: AXID.compoundWorkoutSetupStart)
            .allElementsBoundByIndex
        let startButton = startButtons.last ?? app.descendants(matching: .any)[AXID.compoundWorkoutSetupStart].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Compound start button should exist")
        XCTAssertTrue(
            waitForEnabled(startButton, timeout: 5),
            "Compound start should enable after two selections"
        )
        startButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.compoundWorkoutScreen].firstMatch.waitForExistence(timeout: 10),
            "Compound workout screen should open"
        )
    }

    func testCardioFlowReachesSummary() throws {
        openExerciseSingleExercisePicker()
        XCTAssertTrue(app.fillTextInput(AXID.pickerSearchField, with: "Running"), "Picker search should accept Running")
        dismissSearchKeyboardIfPresent()

        let detailButton = app.descendants(matching: .any)[AXID.pickerExerciseDetailButton(Fixture.runningID)].firstMatch
        XCTAssertTrue(
            app.scrollToHittablePickerElementIfNeeded(AXID.pickerExerciseDetailButton(Fixture.runningID), maxSwipes: 8),
            "Running detail button should be reachable"
        )
        XCTAssertTrue(detailButton.waitForExistence(timeout: 8), "Running detail button should exist")
        detailButton.tap()

        let detailScreen = app.descendants(matching: .any)[AXID.exerciseDetailScreen].firstMatch
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 8), "Exercise detail sheet should appear for Running")

        let detailStartButton = app.descendants(matching: .any)[AXID.exerciseDetailStart].firstMatch
        XCTAssertTrue(detailStartButton.waitForExistence(timeout: 5), "Exercise detail start button should exist")
        detailStartButton.tap()

        let cardioStartScreen = app.descendants(matching: .any)[AXID.cardioStartScreen].firstMatch
        XCTAssertTrue(cardioStartScreen.waitForExistence(timeout: 10), "Cardio start sheet should appear")

        let indoorButton = app.buttons[AXID.cardioStartIndoor].firstMatch
        XCTAssertTrue(indoorButton.waitForExistence(timeout: 5), "Indoor cardio start button should exist")
        indoorButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.cardioSessionScreen].firstMatch.waitForExistence(timeout: 10),
            "Cardio session should start"
        )

        let cardioSessionEndButton = app.descendants(matching: .any)[AXID.cardioSessionEnd].firstMatch
        XCTAssertTrue(cardioSessionEndButton.waitForExistence(timeout: 5), "Cardio end button should exist")
        cardioSessionEndButton.tap()
        let endWorkout = app.descendants(matching: .any)[AXID.cardioSessionConfirmEnd].firstMatch
        XCTAssertTrue(endWorkout.waitForExistence(timeout: 5), "End Workout confirmation should appear")
        endWorkout.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.cardioSessionSummaryScreen].firstMatch.waitForExistence(timeout: 10),
            "Cardio summary should appear after ending session"
        )
    }

    func testUserCategoryManagementCreatesCategory() throws {
        openExerciseViewFromRecentWorkouts()

        let categoriesButton = app.descendants(matching: .any)[AXID.exerciseToolbarCategories].firstMatch
        XCTAssertTrue(categoriesButton.waitForExistence(timeout: 5), "Categories toolbar button should exist")
        categoriesButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.userCategoryManagementScreen].firstMatch.waitForExistence(timeout: 8),
            "User category management should appear"
        )

        app.descendants(matching: .any)[AXID.userCategoryAdd].firstMatch.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.userCategoryEditScreen].firstMatch.waitForExistence(timeout: 8),
            "Category edit screen should appear"
        )
        XCTAssertTrue(app.fillTextInput(AXID.userCategoryName, with: Fixture.createdCategory), "Category name should be editable")
        app.descendants(matching: .any)[AXID.userCategorySave].firstMatch.tap()

        XCTAssertTrue(app.staticTexts[Fixture.createdCategory].firstMatch.waitForExistence(timeout: 8), "Created category should appear")
    }

    func testNotificationWorkoutRouteOpensMockWorkoutDetail() throws {
        openNotificationHub()

        let workoutRouteRow = app.buttons[AXID.notificationWorkoutRow(Fixture.notificationWorkoutRouteID)].firstMatch
        XCTAssertTrue(workoutRouteRow.waitForExistence(timeout: 8), "Workout route notification should exist")
        workoutRouteRow.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.healthkitWorkoutDetailScreen].firstMatch.waitForExistence(timeout: 10),
            "Mock HealthKit workout detail should open from notification"
        )
    }

    func testNotificationMissingWorkoutRouteShowsFallback() throws {
        openNotificationHub()

        let missingRouteRow = app.buttons[AXID.notificationWorkoutRow(Fixture.notificationMissingRouteID)].firstMatch
        XCTAssertTrue(missingRouteRow.waitForExistence(timeout: 8), "Missing route notification should exist")
        missingRouteRow.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.notificationTargetNotFoundScreen].firstMatch.waitForExistence(timeout: 10),
            "Missing workout route should open fallback screen"
        )
    }

    // MARK: - Helpers

    private func openTrainingReadinessDetail() {
        ensureActivityRoot()
        let readinessHero = waitForElement(AXID.activityHeroReadiness, timeout: 15)
        readinessHero.tap()

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
        section.tap()

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
                backButton.tap()
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
        addButton.tap()

        let picker = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8), "Quick Start picker should appear")
    }

    private func openExerciseViewFromRecentWorkouts() {
        ensureActivityRoot()
        let seeAllButton = app.buttons[AXID.activityRecentSeeAll].firstMatch
        let exerciseScreen = app.descendants(matching: .any)[AXID.exerciseViewScreen].firstMatch
        let exerciseToolbarAdd = app.descendants(matching: .any)[AXID.exerciseToolbarAdd].firstMatch
        for _ in 0..<2 {
            XCTAssertTrue(
                app.scrollToHittableElementIfNeeded(AXID.activityRecentSeeAll, maxSwipes: 10),
                "Recent workouts See All should be reachable and tappable"
            )
            XCTAssertTrue(seeAllButton.waitForExistence(timeout: 5), "Recent workouts See All should exist")
            for _ in 0..<2 {
                XCTAssertTrue(waitForHittable(seeAllButton, timeout: 2), "Recent workouts See All should be hittable")
                seeAllButton.tap()

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
        addMenu.tap()

        let singleExerciseOption = app.descendants(matching: .any)[AXID.exerciseMenuSingle].firstMatch
        XCTAssertTrue(singleExerciseOption.waitForExistence(timeout: 5), "Single Exercise menu item should exist")
        singleExerciseOption.tap()

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
        detailButton.tap()

        let detailScreen = app.descendants(matching: .any)[AXID.exerciseDetailScreen].firstMatch
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 8), "Exercise detail sheet should appear")

        let detailStartButton = app.descendants(matching: .any)[AXID.exerciseDetailStart].firstMatch
        XCTAssertTrue(detailStartButton.waitForExistence(timeout: 5), "Exercise detail start button should exist")
        detailStartButton.tap()

        let exerciseStartScreen = app.descendants(matching: .any)[AXID.exerciseStartScreen].firstMatch
        XCTAssertTrue(exerciseStartScreen.waitForExistence(timeout: 10), "Exercise start sheet should appear")

        let startButton = app.buttons[AXID.exerciseStartButton].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Exercise start button should exist")
        startButton.tap()
    }

    private func dismissSearchKeyboardIfPresent() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.waitForExistence(timeout: 1) else { return }

        let exactCandidates = [
            keyboard.buttons["Search"],
            keyboard.buttons["search"]
        ]

        if let button = exactCandidates.first(where: \.exists) {
            button.tap()
            return
        }

        let searchButton = keyboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'search'")).firstMatch
        if searchButton.exists {
            searchButton.tap()
        }
    }

    private func openTemplateList() {
        openExerciseViewFromRecentWorkouts()
        let templatesButton = app.descendants(matching: .any)[AXID.exerciseToolbarTemplates].firstMatch
        XCTAssertTrue(templatesButton.waitForExistence(timeout: 5), "Templates toolbar button should exist")
        templatesButton.tap()

        let templateScreen = app.descendants(matching: .any)[AXID.workoutTemplateListScreen].firstMatch
        XCTAssertTrue(templateScreen.waitForExistence(timeout: 8), "Template list screen should appear")
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
        pickerRow.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.compoundWorkoutSetupScreen].firstMatch.waitForExistence(timeout: 8),
            "Compound setup should return after picker selection"
        )
    }

    private func openNotificationHub() {
        navigateToDashboard()
        let dashboardHero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(dashboardHero.waitForExistence(timeout: 12), "Dashboard hero should appear before opening notifications")

        dismissMorningBriefingIfNeeded()

        let notificationsButton = app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(notificationsButton.waitForExistence(timeout: 5), "Notifications button should exist on the dashboard")
        XCTAssertTrue(waitForHittable(notificationsButton, timeout: 8), "Notifications button should be tappable")
        notificationsButton.tap()

        let hub = app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
        XCTAssertTrue(hub.waitForExistence(timeout: 8), "Notification hub should appear")
    }

    private func tapBackButton() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button should exist")
        backButton.tap()
    }

    private func openCompoundPicker(using button: XCUIElement, in container: XCUIElement, maxSwipes: Int = 6) -> Bool {
        let picker = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch

        if button.isHittable {
            button.tap()
            return picker.waitForExistence(timeout: 5)
        }

        for _ in 0..<maxSwipes {
            if button.exists {
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                if picker.waitForExistence(timeout: 2) {
                    return true
                }
            }
            container.swipeUp()
        }

        for _ in 0..<maxSwipes {
            if button.exists {
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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

    private func dismissMorningBriefingIfNeeded() {
        let briefingScreen = app.descendants(matching: .any)[AXID.dashboardMorningBriefingScreen].firstMatch
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if briefingScreen.exists { break }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        guard briefingScreen.exists else { return }

        let dismissButton = app.descendants(matching: .any)[AXID.dashboardMorningBriefingDismiss].firstMatch
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 2), "Morning Briefing dismiss button should exist")
        dismissButton.tap()

        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: briefingScreen)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed,
            "Morning Briefing should dismiss before opening notifications"
        )
    }

}
