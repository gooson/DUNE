@preconcurrency import XCTest

@MainActor
final class ActivityExercisePickerRegressionTests: ActivityExerciseSeededUITestBaseCase {
    private enum Fixture {
        static let benchPressID = "barbell-bench-press"
        static let singleTemplateID = "22222222-2222-4222-8222-222222222222"
        static let customExerciseName = "Codex Cable Raise"
        static let customCategoryID = "11111111-1111-4111-8111-111111111111"
        static let createdTemplateName = "Codex Picker Template"
    }

    func testQuickStartPickerShowsHubSectionsAndStartsTemplateLane() throws {
        openQuickStartPicker()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.pickerSectionRecent].firstMatch.waitForExistence(timeout: 8),
            "Quick start picker should expose the recent section"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.pickerSectionTemplates].firstMatch.waitForExistence(timeout: 8),
            "Quick start picker should expose the templates section when seeded templates exist"
        )
        XCTAssertTrue(
            scrollPickerToElementIfNeeded(AXID.pickerSectionPopular),
            "Quick start picker should expose the popular section"
        )

        let templateRow = app.descendants(matching: .any)[AXID.pickerTemplateRow(Fixture.singleTemplateID)].firstMatch
        XCTAssertTrue(
            scrollPickerToHittableElementIfNeeded(
                AXID.pickerTemplateRow(Fixture.singleTemplateID),
                direction: .down
            ),
            "Seeded single template row should be reachable in picker"
        )
        templateRow.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseStartScreen].firstMatch.waitForExistence(timeout: 10),
            "Selecting a single-exercise template from quick start should open Exercise Start"
        )
    }

    func testQuickStartPickerCanRevealAllExercisesAndOpenDetail() throws {
        openQuickStartPicker()

        XCTAssertTrue(
            scrollPickerToHittableElementIfNeeded(AXID.pickerAllExercisesButton, maxSwipes: 6),
            "All Exercises button should be reachable in quick start hub"
        )
        let allExercisesButton = app.descendants(matching: .any)[AXID.pickerAllExercisesButton].firstMatch
        XCTAssertTrue(allExercisesButton.waitForExistence(timeout: 8), "All Exercises button should exist in quick start hub")
        allExercisesButton.tap()

        XCTAssertTrue(
            scrollPickerToHittableElementIfNeeded(AXID.pickerHideAllButton, maxSwipes: 4, direction: .down),
            "Quick start picker should expose the Hide action after revealing all exercises"
        )

        let hideButton = app.descendants(matching: .any)[AXID.pickerHideAllButton].firstMatch
        XCTAssertTrue(hideButton.waitForExistence(timeout: 8), "Hide button should exist after revealing all exercises")
        hideButton.tap()

        XCTAssertTrue(
            scrollPickerToElementIfNeeded(AXID.pickerAllExercisesButton, maxSwipes: 4, direction: .down),
            "Quick start picker should restore the hub entry after hiding all exercises"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.pickerAllExercisesButton].firstMatch.waitForExistence(timeout: 8),
            "Quick start picker should return to the hub after hiding all exercises"
        )

        XCTAssertTrue(app.fillTextInput(AXID.pickerSearchField, with: "Bench Press"), "Picker search should accept Bench Press")
        dismissSearchKeyboardIfPresent()

        XCTAssertTrue(
            scrollPickerToHittableElementIfNeeded(AXID.pickerExerciseDetailButton(Fixture.benchPressID), maxSwipes: 4),
            "Bench Press detail button should be reachable after search"
        )
        let detailButton = app.descendants(matching: .any)[AXID.pickerExerciseDetailButton(Fixture.benchPressID)].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 8), "Bench Press detail button should exist after search")
        detailButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseDetailScreen].firstMatch.waitForExistence(timeout: 8),
            "Exercise detail sheet should appear from picker search results"
        )

        let closeButton = app.descendants(matching: .any)[AXID.exerciseDetailClose].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Exercise detail close button should exist")
        closeButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.pickerRootList].firstMatch.waitForExistence(timeout: 8),
            "Closing the detail sheet should return to the picker"
        )
    }

    func testFullPickerSupportsFilterSelectorsAndSelectionFromTemplateForm() throws {
        executionTimeAllowance = 180
        openTemplateFormPicker(prefillName: Fixture.createdTemplateName)

        let createCustomButton = app.descendants(matching: .any)[AXID.pickerCreateCustomButton].firstMatch
        XCTAssertTrue(createCustomButton.waitForExistence(timeout: 8), "Full picker should expose create custom CTA")

        XCTAssertTrue(
            tapHorizontalPickerChip(AXID.pickerFilterCategory("strength"), in: AXID.pickerFilterCategoryScroll),
            "Strength category chip should be tappable"
        )

        let clearFiltersButton = app.descendants(matching: .any)[AXID.pickerClearFilters].firstMatch
        XCTAssertTrue(clearFiltersButton.waitForExistence(timeout: 8), "Clear Filters action should appear after applying filters")

        let customExerciseRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", Fixture.customExerciseName)).firstMatch
        XCTAssertTrue(customExerciseRow.waitForExistence(timeout: 8), "Filtered picker should surface the seeded custom exercise")

        clearFiltersButton.tap()

        XCTAssertTrue(
            tapHorizontalPickerChip(
                AXID.pickerFilterUserCategory(Fixture.customCategoryID),
                in: AXID.pickerFilterCategoryScroll
            ),
            "User category chip should be tappable in the category rail"
        )
        XCTAssertTrue(customExerciseRow.waitForExistence(timeout: 8), "User category filter should keep the seeded custom exercise visible")
        customExerciseRow.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch.waitForExistence(timeout: 8),
            "Selecting an exercise from the full picker should return to the template form"
        )

        let saveButton = app.buttons[AXID.templateFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Template save button should exist")
        XCTAssertTrue(saveButton.isEnabled, "Template save should enable after one picked exercise and a name")
    }

    func testVisualAuditLibraryPickerDetailAtNormalText() throws {
        try auditLibraryPickerDetail(maximumText: false)
    }

    private func auditLibraryPickerDetail(maximumText: Bool) throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in B09 native visual audit only") }
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName",
            maximumText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"
        ]
        launchApp(with: configuration)
        openExerciseViewFromRecentWorkouts()
        let size = maximumText ? "MAX" : "normal"
        XCTAssertTrue(app.descendants(matching: .any)[AXID.exerciseViewScreen].firstMatch.exists)
        VisualAudit.capture("W01 \(size) exercise library")

        let add = app.descendants(matching: .any)[AXID.exerciseToolbarAdd].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 8) && add.isHittable)
        add.auditTap()
        let single = app.descendants(matching: .any)[AXID.exerciseMenuSingle].firstMatch
        XCTAssertTrue(single.waitForExistence(timeout: 5))
        single.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.pickerRootList].firstMatch.waitForExistence(timeout: 8))
        VisualAudit.capture("W02 \(size) exercise picker")

        XCTAssertTrue(app.fillTextInput(AXID.pickerSearchField, with: "Bench Press"))
        dismissSearchKeyboardIfPresent()
        XCTAssertTrue(scrollPickerToHittableElementIfNeeded(
            AXID.pickerExerciseDetailButton(Fixture.benchPressID), maxSwipes: 10
        ))
        let info = app.descendants(matching: .any)[AXID.pickerExerciseDetailButton(Fixture.benchPressID)].firstMatch
        XCTAssertTrue(info.isHittable)
        VisualAudit.capture("W02 \(size) filtered Bench Press info")
        info.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.exerciseDetailScreen].firstMatch.waitForExistence(timeout: 8))
        let close = app.descendants(matching: .any)[AXID.exerciseDetailClose].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5) && close.isHittable)
        VisualAudit.capture("W03 \(size) exercise detail")
        close.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.pickerRootList].firstMatch.waitForExistence(timeout: 8))
        if maximumText {
            let rowID = AXID.pickerExerciseRow(Fixture.benchPressID)
            XCTAssertTrue(scrollPickerToHittableElementIfNeeded(rowID, maxSwipes: 10))
            let row = app.descendants(matching: .any)[rowID].firstMatch
            XCTAssertTrue(row.isHittable)
            row.auditTap()
            XCTAssertTrue(app.descendants(matching: .any)[AXID.exerciseStartScreen].firstMatch.waitForExistence(timeout: 10),
                          "Selecting the original exercise row should open Exercise Start")
        } else {
            let cancel = app.descendants(matching: .any)[AXID.pickerCancelButton].firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 5) && cancel.isHittable)
            cancel.auditTap()
            XCTAssertTrue(app.descendants(matching: .any)[AXID.exerciseViewScreen].firstMatch.waitForExistence(timeout: 8))
        }
    }

    func testVisualAuditLibraryPickerDetailAtMaximumText() throws {
        try auditLibraryPickerDetail(maximumText: true)
    }

    func testVisualAuditCustomCreateAtNormalText() throws {
        try auditCustomCreate(maximumText: false)
    }

    func testVisualAuditCustomCreateAtMaximumText() throws {
        try auditCustomCreate(maximumText: true)
    }

    private func auditCustomCreate(maximumText: Bool) throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in B09 native visual audit only") }
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName",
            maximumText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"
        ]
        launchApp(with: configuration)
        if maximumText || app.windows.firstMatch.frame.width >= 600 {
            openAuditFullPicker()
        } else {
            openTemplateFormPicker()
        }
        let createCustom = app.descendants(matching: .any)[AXID.pickerCreateCustomButton].firstMatch
        XCTAssertTrue(scrollPickerToHittableElementIfNeeded(AXID.pickerCreateCustomButton, maxSwipes: 10))
        XCTAssertTrue(createCustom.waitForExistence(timeout: 5) && createCustom.isHittable)
        createCustom.auditTap()
        let form = app.descendants(matching: .any)[AXID.createCustomExerciseScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8))
        let size = maximumText ? "MAX" : "normal"
        VisualAudit.capture("W04 \(size) custom exercise form")

        let create = app.descendants(matching: .any)[AXID.createCustomExerciseCreate].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        XCTAssertFalse(create.isEnabled, "Empty exercise name must keep Create disabled")
        if maximumText {
            let labeledMenu = app.buttons.matching(NSPredicate(
                format: "label CONTAINS[c] %@", "Category"
            )).firstMatch
            let categoryMenu = labeledMenu.exists ? labeledMenu : app.buttons["Strength"].firstMatch
            XCTAssertTrue(categoryMenu.waitForExistence(timeout: 5), "Category menu must be reachable at MAX")
            categoryMenu.auditTap()
            let cardio = app.buttons["Cardio"].firstMatch
            XCTAssertTrue(cardio.waitForExistence(timeout: 5))
            cardio.auditTap()
            XCTAssertTrue(app.buttons.matching(NSPredicate(
                format: "label CONTAINS[c] %@", "Cardio"
            )).firstMatch.exists, "Collapsed menu must show Cardio selection")
        } else {
            let categorySegments = app.segmentedControls.firstMatch
            XCTAssertTrue(categorySegments.waitForExistence(timeout: 5))
            let cardio = categorySegments.buttons["Cardio"].firstMatch
            XCTAssertTrue(cardio.waitForExistence(timeout: 5))
            cardio.auditTap()
            XCTAssertTrue(cardio.isSelected, "Cardio segment must be selected")
        }
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] %@", "Duration + Distance"
        )).firstMatch.waitForExistence(timeout: 5), "Cardio should reset the original input type")
        XCTAssertFalse(create.isEnabled, "Changing category must not enable Create with an empty name")
        VisualAudit.capture("W04 \(size) Cardio category readback")

        let cancel = app.navigationBars["New Exercise"].buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5) && cancel.isHittable)
        cancel.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.pickerRootList].firstMatch.waitForExistence(timeout: 8),
                      "Cancel must return to the picker without creating an exercise")
    }

    private func openAuditFullPicker() {
        openExerciseViewFromRecentWorkouts()

        let templatesButton = app.descendants(matching: .any)[AXID.exerciseToolbarTemplates].firstMatch
        if templatesButton.exists && templatesButton.isHittable {
            templatesButton.auditTap()
        } else {
            XCTAssertTrue(app.waitAndTapExerciseSecondaryAction(AXID.exerciseToolbarTemplates, timeout: 8),
                          "Templates action should be reachable through the Exercise secondary menu")
        }
        let templateList = app.descendants(matching: .any)[AXID.workoutTemplateListScreen].firstMatch
        XCTAssertTrue(templateList.waitForExistence(timeout: 8))
        let addTemplate = app.descendants(matching: .any)[AXID.workoutTemplateListAdd].firstMatch
        XCTAssertTrue(addTemplate.waitForExistence(timeout: 5))
        addTemplate.auditTap()

        let form = app.collectionViews[AXID.templateFormScreen].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 8))
        let addExercise = app.descendants(matching: .any)[AXID.templateFormAddExercise].firstMatch
        for _ in 0..<12 where !(addExercise.exists && addExercise.isHittable) {
            form.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(addExercise.exists && addExercise.isHittable,
                      "Add Exercise should be reachable after scrolling the template Form")
        addExercise.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.pickerRootList].firstMatch.waitForExistence(timeout: 8))
    }

    // MARK: - Helpers

    private func ensureActivityRoot() {
        let hero = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Activity hero should exist")
    }

    private func openQuickStartPicker() {
        ensureActivityRoot()

        XCTAssertTrue(app.waitAndTap(AXID.activityToolbarAdd), "Activity add button should exist")

        let picker = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8), "Quick start picker should appear")
    }

    private func openExerciseViewFromRecentWorkouts() {
        ensureActivityRoot()
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.activityRecentSeeAll, maxSwipes: 10))

        let seeAllButton = app.buttons[AXID.activityRecentSeeAll].firstMatch
        XCTAssertTrue(seeAllButton.waitForExistence(timeout: 5), "Recent workouts See All should be reachable")
        seeAllButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseViewScreen].firstMatch.waitForExistence(timeout: 10),
            "Exercise screen should appear from Activity"
        )
    }

    private func openTemplateFormPicker(prefillName: String? = nil) {
        openExerciseViewFromRecentWorkouts()

        XCTAssertTrue(app.waitAndTapExerciseSecondaryAction(AXID.exerciseToolbarTemplates),
                      "Templates route should open through its visible toolbar action")

        let templateList = app.descendants(matching: .any)[AXID.workoutTemplateListScreen].firstMatch
        XCTAssertTrue(templateList.waitForExistence(timeout: 8), "Template list should appear")

        let addButton = app.descendants(matching: .any)[AXID.workoutTemplateListAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Template add button should exist")
        addButton.tap()

        let templateForm = app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch
        XCTAssertTrue(templateForm.waitForExistence(timeout: 8), "Template form should appear")

        if let prefillName {
            XCTAssertTrue(
                app.fillTextInput(AXID.templateFormName, with: prefillName),
                "Template form name should be editable before opening the full picker"
            )
        }

        let addExerciseButton = app.descendants(matching: .any)[AXID.templateFormAddExercise].firstMatch
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5), "Add Exercise button should exist in template form")
        addExerciseButton.auditTap()

        let picker = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8), "Full picker should appear from template form")
        VisualAudit.capture("Template exercise picker")
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

    private func tapHorizontalPickerChip(
        _ identifier: String,
        in containerIdentifier: String,
        maxSwipes: Int = 8
    ) -> Bool {
        _ = scrollPickerToElementIfNeeded(containerIdentifier, maxSwipes: 6)
        let container = app.descendants(matching: .any)[containerIdentifier].firstMatch
        guard container.waitForExistence(timeout: 5) else { return false }

        let chip = app.descendants(matching: .any)[identifier].firstMatch
        if chip.exists && chip.isHittable {
            chip.tap()
            return true
        }

        for _ in 0..<maxSwipes {
            container.swipeLeft()
            if chip.exists && chip.isHittable {
                chip.tap()
                return true
            }
        }

        for _ in 0..<maxSwipes {
            container.swipeRight()
            if chip.exists && chip.isHittable {
                chip.tap()
                return true
            }
        }

        return false
    }

    private func scrollPickerToElementIfNeeded(
        _ identifier: String,
        maxSwipes: Int = 6,
        direction: ScrollDirection = .up,
        timeoutPerCheck: TimeInterval = 0.25
    ) -> Bool {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        let pickerList = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch

        guard pickerList.waitForExistence(timeout: 5) else {
            return element.exists
        }

        for _ in 0..<maxSwipes {
            if element.exists || element.waitForExistence(timeout: timeoutPerCheck) {
                return true
            }

            switch direction {
            case .up:
                pickerList.swipeUp()
            case .down:
                pickerList.swipeDown()
            }
        }

        return element.exists
    }

    private func scrollPickerToHittableElementIfNeeded(
        _ identifier: String,
        maxSwipes: Int = 6,
        direction: ScrollDirection = .up,
        timeoutPerCheck: TimeInterval = 0.25
    ) -> Bool {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        guard scrollPickerToElementIfNeeded(
            identifier,
            maxSwipes: maxSwipes,
            direction: direction,
            timeoutPerCheck: timeoutPerCheck
        ) else {
            return false
        }

        let pickerList = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        guard pickerList.waitForExistence(timeout: 5) else {
            return element.exists && element.isHittable
        }

        for _ in 0..<maxSwipes where !(element.exists && element.isHittable) {
            switch direction {
            case .up:
                pickerList.swipeUp()
            case .down:
                pickerList.swipeDown()
            }
        }

        return element.exists && element.isHittable
    }
}
