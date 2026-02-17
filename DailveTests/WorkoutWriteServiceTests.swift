import Foundation
import Testing
import HealthKit
@testable import Dailve

// MARK: - ExerciseCategory HK Mapping Tests

@Suite("ExerciseCategory HK Activity Type Mapping")
struct ExerciseCategoryHKMappingTests {

    @Test("Strength maps to traditionalStrengthTraining")
    func strengthMapping() {
        let result = ExerciseCategory.hkActivityType(category: .strength, exerciseName: "Bench Press")
        #expect(result == .traditionalStrengthTraining)
    }

    @Test("HIIT maps to highIntensityIntervalTraining")
    func hiitMapping() {
        let result = ExerciseCategory.hkActivityType(category: .hiit, exerciseName: "Burpees")
        #expect(result == .highIntensityIntervalTraining)
    }

    @Test("Flexibility maps to flexibility")
    func flexibilityMapping() {
        let result = ExerciseCategory.hkActivityType(category: .flexibility, exerciseName: "Static Stretch")
        #expect(result == .flexibility)
    }

    @Test("Bodyweight maps to functionalStrengthTraining")
    func bodyweightMapping() {
        let result = ExerciseCategory.hkActivityType(category: .bodyweight, exerciseName: "Push Up")
        #expect(result == .functionalStrengthTraining)
    }

    @Test("Cardio without name match falls back to .other")
    func cardioFallback() {
        let result = ExerciseCategory.hkActivityType(category: .cardio, exerciseName: "Jump Rope")
        #expect(result == .other)
    }

    // MARK: - Name Override Tests

    @Test("Running name overrides category")
    func runningOverride() {
        let result = ExerciseCategory.hkActivityType(category: .cardio, exerciseName: "Running")
        #expect(result == .running)
    }

    @Test("Walking name overrides category")
    func walkingOverride() {
        let result = ExerciseCategory.hkActivityType(category: .cardio, exerciseName: "Walking")
        #expect(result == .walking)
    }

    @Test("Cycling name overrides category")
    func cyclingOverride() {
        let result = ExerciseCategory.hkActivityType(category: .cardio, exerciseName: "Cycling")
        #expect(result == .cycling)
    }

    @Test("Swimming name overrides category")
    func swimmingOverride() {
        let result = ExerciseCategory.hkActivityType(category: .cardio, exerciseName: "Swimming")
        #expect(result == .swimming)
    }

    @Test("Hiking name overrides category")
    func hikingOverride() {
        let result = ExerciseCategory.hkActivityType(category: .cardio, exerciseName: "Hiking")
        #expect(result == .hiking)
    }

    @Test("Yoga name overrides category")
    func yogaOverride() {
        let result = ExerciseCategory.hkActivityType(category: .flexibility, exerciseName: "Yoga")
        #expect(result == .yoga)
    }

    @Test("Rowing name overrides category")
    func rowingOverride() {
        let result = ExerciseCategory.hkActivityType(category: .cardio, exerciseName: "Rowing")
        #expect(result == .rowing)
    }

    @Test("Elliptical name overrides category")
    func ellipticalOverride() {
        let result = ExerciseCategory.hkActivityType(category: .cardio, exerciseName: "Elliptical")
        #expect(result == .elliptical)
    }

    @Test("Pilates name overrides category")
    func pilatesOverride() {
        let result = ExerciseCategory.hkActivityType(category: .flexibility, exerciseName: "Pilates")
        #expect(result == .pilates)
    }

    @Test("Dance name overrides category")
    func danceOverride() {
        let result = ExerciseCategory.hkActivityType(category: .cardio, exerciseName: "Dance")
        #expect(result == .socialDance)
    }

    @Test("Core name overrides category")
    func coreOverride() {
        let result = ExerciseCategory.hkActivityType(category: .bodyweight, exerciseName: "Core Stability")
        #expect(result == .coreTraining)
    }

    @Test("Partial name match works (contains 'run')")
    func partialNameMatch() {
        let result = ExerciseCategory.hkActivityType(category: .cardio, exerciseName: "Trail Run")
        #expect(result == .running)
    }

    @Test("Case insensitive name matching")
    func caseInsensitive() {
        let result = ExerciseCategory.hkActivityType(category: .cardio, exerciseName: "CYCLING")
        #expect(result == .cycling)
    }

    @Test("Unknown name falls back to category default")
    func unknownNameFallback() {
        let result = ExerciseCategory.hkActivityType(category: .strength, exerciseName: "Custom Exercise XYZ")
        #expect(result == .traditionalStrengthTraining)
    }
}

// MARK: - WorkoutWriteInput Validation Tests

@Suite("WorkoutWriteInput Validation")
struct WorkoutWriteInputValidationTests {

    @Test("isFromHealthKit flag is preserved")
    func healthKitOriginFlag() {
        let input = WorkoutWriteInput(
            startDate: Date(),
            duration: 3600,
            category: .strength,
            exerciseName: "Bench Press",
            estimatedCalories: 250,
            isFromHealthKit: true
        )
        #expect(input.isFromHealthKit == true)
    }

    @Test("Zero duration is detectable")
    func zeroDuration() {
        let input = WorkoutWriteInput(
            startDate: Date(),
            duration: 0,
            category: .strength,
            exerciseName: "Squat",
            estimatedCalories: nil,
            isFromHealthKit: false
        )
        #expect(input.duration <= 0)
    }

    @Test("Duration over 8 hours is detectable")
    func excessiveDuration() {
        let input = WorkoutWriteInput(
            startDate: Date(),
            duration: 28801,
            category: .strength,
            exerciseName: "Squat",
            estimatedCalories: nil,
            isFromHealthKit: false
        )
        #expect(input.duration > 28800)
    }

    @Test("Nil calories is valid input")
    func nilCalories() {
        let input = WorkoutWriteInput(
            startDate: Date(),
            duration: 1800,
            category: .cardio,
            exerciseName: "Running",
            estimatedCalories: nil,
            isFromHealthKit: false
        )
        #expect(input.estimatedCalories == nil)
    }

    @Test("Valid input has all fields set correctly")
    func validInput() {
        let date = Date()
        let input = WorkoutWriteInput(
            startDate: date,
            duration: 3600,
            category: .strength,
            exerciseName: "Deadlift",
            estimatedCalories: 350.5,
            isFromHealthKit: false
        )
        #expect(input.startDate == date)
        #expect(input.duration == 3600)
        #expect(input.category == .strength)
        #expect(input.exerciseName == "Deadlift")
        #expect(input.estimatedCalories == 350.5)
        #expect(input.isFromHealthKit == false)
    }
}
