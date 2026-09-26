@preconcurrency import XCTest

@MainActor
final class WorkoutProgressionRegressionUITests: ActivityExerciseSeededUITestBaseCase {
    private enum Fixture {
        static let templateID = "22222222-2222-4222-8222-222222222222"
        static let plannedReps = 8
        static let startingWeight = 60.0
        static let missedTargetWeight = 55.0
    }

    func testMissedTargetKeepsPlanAndRequiresApplyingLowerWeight() throws {
        openSeededStrengthTemplate()

        let plannedReps = waitForElement(AXID.workoutSessionPlannedReps)
        XCTAssertTrue(plannedReps.label.contains(String(Fixture.plannedReps)))
        XCTAssertEqual(try enteredWeight(), Fixture.startingWeight)

        XCTAssertTrue(app.fillTextInput(AXID.workoutSessionField("reps"), with: "6"))
        dismissWorkoutKeyboard()
        XCTAssertEqual(app.textFields[AXID.workoutSessionField("reps")].value as? String, "6")
        XCTAssertTrue(plannedReps.label.contains(String(Fixture.plannedReps)), "Editing actual reps must preserve the planned target")

        completeFirstSetAndSkipRest()

        XCTAssertTrue(waitForElement(AXID.workoutSessionPlannedReps).label.contains(String(Fixture.plannedReps)))
        XCTAssertTrue(waitForElement(AXID.workoutSessionRecommendationReason).exists)
        let applyButton = app.buttons[AXID.workoutSessionApplyRecommendation].firstMatch
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5))
        XCTAssertEqual(try enteredWeight(), Fixture.startingWeight, "The recommendation must not change the next set automatically")

        applyButton.tap()
        XCTAssertEqual(try enteredWeight(), Fixture.missedTargetWeight)
    }

    func testMeetingTargetDoesNotAutomaticallyIncreaseNextSetWeight() throws {
        openSeededStrengthTemplate()

        XCTAssertTrue(waitForElement(AXID.workoutSessionPlannedReps).label.contains(String(Fixture.plannedReps)))
        XCTAssertEqual(try enteredWeight(), Fixture.startingWeight)
        completeFirstSetAndSkipRest()

        XCTAssertTrue(waitForElement(AXID.workoutSessionRecommendationReason).exists)
        XCTAssertTrue(app.buttons[AXID.workoutSessionApplyRecommendation].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(try enteredWeight(), Fixture.startingWeight, "Meeting the target without a user effort rating must not raise the weight")
    }

    private func openSeededStrengthTemplate() {
        XCTAssertTrue(app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.waitAndTap(AXID.activityToolbarAdd))
        XCTAssertTrue(app.descendants(matching: .any)[AXID.pickerRootList].firstMatch.waitForExistence(timeout: 8))

        let templateID = AXID.pickerTemplateRow(Fixture.templateID)
        XCTAssertTrue(app.scrollToHittablePickerElementIfNeeded(templateID, maxSwipes: 8))
        let template = app.buttons[templateID].firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AXID.exerciseStartScreen].firstMatch.waitForExistence(timeout: 10))
        let start = app.buttons[AXID.exerciseStartButton].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.workoutSessionScreen].firstMatch.waitForExistence(timeout: 10))

        let unit = app.buttons["workout-weight-unit-button"].firstMatch
        XCTAssertTrue(unit.waitForExistence(timeout: 5))
        if unit.label.uppercased().contains("LB") { unit.tap() }
    }

    private func completeFirstSetAndSkipRest() {
        let complete = app.buttons[AXID.workoutSessionCompleteSet].firstMatch
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()

        let skip = app.buttons[AXID.workoutSessionSkipRest].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "The first of two seeded sets should start a rest timer")
        skip.tap()
        XCTAssertTrue(app.textFields[AXID.workoutSessionField("kg")].firstMatch.waitForExistence(timeout: 5))
    }

    private func enteredWeight() throws -> Double {
        let field = app.textFields[AXID.workoutSessionField("kg")].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        return try XCTUnwrap(Double(try XCTUnwrap(field.value as? String)))
    }

    private func dismissWorkoutKeyboard() {
        let done = app.buttons["workout-keyboard-done-button"].firstMatch
        if done.waitForExistence(timeout: 2) { done.tap() }
    }
}
