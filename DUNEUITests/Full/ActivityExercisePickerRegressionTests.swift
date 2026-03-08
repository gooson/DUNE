@preconcurrency import XCTest

@MainActor
final class ActivityExercisePickerRegressionTests: ActivityExerciseSeededUITestBaseCase {
    private enum Fixture {
        static let benchPressID = "barbell-bench-press"
        static let singleTemplateSlug = "codex-strength-starter"
        static let customExerciseName = "Codex Cable Raise"
        static let customCategorySlug = "codex-mobility"
        static let createdTemplateName = "Codex Picker Template"
    }

    func testQuickStartPickerShowsHubSectionsAndStartsTemplateLane() throws {
        openQuickStartPicker()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.pickerSectionRecent].firstMatch.waitForExistence(timeout: 8),
            "Quick start picker should expose the recent section"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.pickerSectionPopular].firstMatch.waitForExistence(timeout: 8),
            "Quick start picker should expose the popular section"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.pickerSectionTemplates].firstMatch.waitForExistence(timeout: 8),
            "Quick start picker should expose the templates section when seeded templates exist"
        )

        let templateRow = app.descendants(matching: .any)[AXID.pickerTemplateRow(Fixture.singleTemplateSlug)].firstMatch
        XCTAssertTrue(templateRow.waitForExistence(timeout: 8), "Seeded single template row should exist in picker")
        templateRow.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseStartScreen].firstMatch.waitForExistence(timeout: 10),
            "Selecting a single-exercise template from quick start should open Exercise Start"
        )
    }

    func testQuickStartPickerCanRevealAllExercisesAndOpenDetail() throws {
        openQuickStartPicker()

        let allExercisesButton = app.descendants(matching: .any)[AXID.pickerAllExercisesButton].firstMatch
        XCTAssertTrue(allExercisesButton.waitForExistence(timeout: 8), "All Exercises button should exist in quick start hub")
        allExercisesButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.pickerSectionAll].firstMatch.waitForExistence(timeout: 8),
            "Quick start picker should switch to the all-exercises section"
        )

        let hideButton = app.descendants(matching: .any)[AXID.pickerHideAllButton].firstMatch
        XCTAssertTrue(hideButton.waitForExistence(timeout: 8), "Hide button should exist after revealing all exercises")
        hideButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.pickerAllExercisesButton].firstMatch.waitForExistence(timeout: 8),
            "Quick start picker should return to the hub after hiding all exercises"
        )

        XCTAssertTrue(app.fillTextInput(AXID.pickerSearchField, with: "Bench Press"), "Picker search should accept Bench Press")
        dismissSearchKeyboardIfPresent()

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
        openTemplateFormPicker()

        let createCustomButton = app.descendants(matching: .any)[AXID.pickerCreateCustomButton].firstMatch
        XCTAssertTrue(createCustomButton.waitForExistence(timeout: 8), "Full picker should expose create custom CTA")

        XCTAssertTrue(
            tapHorizontalPickerChip(AXID.pickerFilterCategory("strength"), in: AXID.pickerFilterCategoryScroll),
            "Strength category chip should be tappable"
        )
        XCTAssertTrue(
            tapHorizontalPickerChip(AXID.pickerFilterMuscle("shoulders"), in: AXID.pickerFilterMuscleScroll),
            "Shoulders muscle chip should be tappable"
        )
        XCTAssertTrue(
            tapHorizontalPickerChip(AXID.pickerFilterEquipment("cable"), in: AXID.pickerFilterEquipmentScroll),
            "Cable equipment chip should be tappable"
        )

        let clearFiltersButton = app.descendants(matching: .any)[AXID.pickerClearFilters].firstMatch
        XCTAssertTrue(clearFiltersButton.waitForExistence(timeout: 8), "Clear Filters action should appear after applying filters")

        let customExerciseLabel = app.staticTexts[Fixture.customExerciseName].firstMatch
        XCTAssertTrue(customExerciseLabel.waitForExistence(timeout: 8), "Filtered picker should surface the seeded custom exercise")

        clearFiltersButton.tap()

        XCTAssertTrue(
            tapHorizontalPickerChip(
                AXID.pickerFilterUserCategory(Fixture.customCategorySlug),
                in: AXID.pickerFilterCategoryScroll
            ),
            "User category chip should be tappable in the category rail"
        )
        XCTAssertTrue(customExerciseLabel.waitForExistence(timeout: 8), "User category filter should keep the seeded custom exercise visible")

        let customExerciseCell = app.tables.cells.containing(.staticText, identifier: Fixture.customExerciseName).firstMatch
        if customExerciseCell.waitForExistence(timeout: 3) {
            customExerciseCell.tap()
        } else {
            customExerciseLabel.tap()
        }

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch.waitForExistence(timeout: 8),
            "Selecting an exercise from the full picker should return to the template form"
        )
        XCTAssertTrue(
            app.fillTextInput(AXID.templateFormName, with: Fixture.createdTemplateName),
            "Template form name should be editable after returning from picker"
        )

        let saveButton = app.descendants(matching: .any)[AXID.templateFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Template save button should exist")
        XCTAssertTrue(saveButton.isEnabled, "Template save should enable after one picked exercise and a name")
    }

    // MARK: - Helpers

    private func ensureActivityRoot() {
        let hero = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Activity hero should exist")
    }

    private func openQuickStartPicker() {
        ensureActivityRoot()

        let addButton = app.descendants(matching: .any)[AXID.activityToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Activity add button should exist")
        addButton.tap()

        let picker = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8), "Quick start picker should appear")
    }

    private func openExerciseViewFromRecentWorkouts() {
        ensureActivityRoot()
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.activityRecentSeeAll, maxSwipes: 10))

        let seeAllButton = app.descendants(matching: .any)[AXID.activityRecentSeeAll].firstMatch
        XCTAssertTrue(seeAllButton.waitForExistence(timeout: 5), "Recent workouts See All should be reachable")
        seeAllButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseViewScreen].firstMatch.waitForExistence(timeout: 10),
            "Exercise screen should appear from Activity"
        )
    }

    private func openTemplateFormPicker() {
        openExerciseViewFromRecentWorkouts()

        let templatesButton = app.descendants(matching: .any)[AXID.exerciseToolbarTemplates].firstMatch
        XCTAssertTrue(templatesButton.waitForExistence(timeout: 5), "Templates toolbar button should exist")
        templatesButton.tap()

        let templateList = app.descendants(matching: .any)[AXID.workoutTemplateListScreen].firstMatch
        XCTAssertTrue(templateList.waitForExistence(timeout: 8), "Template list should appear")

        let addButton = app.descendants(matching: .any)[AXID.workoutTemplateListAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Template add button should exist")
        addButton.tap()

        let templateForm = app.descendants(matching: .any)[AXID.templateFormScreen].firstMatch
        XCTAssertTrue(templateForm.waitForExistence(timeout: 8), "Template form should appear")

        let addExerciseButton = app.descendants(matching: .any)[AXID.templateFormAddExercise].firstMatch
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5), "Add Exercise button should exist in template form")
        addExerciseButton.tap()

        let picker = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8), "Full picker should appear from template form")
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
}
