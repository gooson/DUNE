import Foundation
import Testing
@testable import DUNE

@Suite("TemplateExerciseResolver")
struct TemplateExerciseResolverTests {
    private func makeCardioDefinition(
        id: String = "stair-climber",
        name: String = "Stair Climber",
        cardioUnit: CardioSecondaryUnit = .floors
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: name,
            category: .cardio,
            inputType: .durationDistance,
            primaryMuscles: [.quadriceps],
            secondaryMuscles: [.glutes],
            equipment: .machine,
            metValue: 9.0,
            cardioSecondaryUnit: cardioUnit
        )
    }

    private func makeStrengthDefinition(
        id: String = "bench-press",
        name: String = "Bench Press"
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: name,
            category: .strength,
            inputType: .weightReps,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps],
            equipment: .barbell,
            metValue: 6.0
        )
    }

    @Test("resolveExercise preserves custom cardio metadata")
    func resolveExercisePreservesCustomCardioMetadata() {
        let custom = CustomExercise(
            name: "Custom Stair",
            category: .cardio,
            inputType: .durationDistance,
            primaryMuscles: [.quadriceps],
            equipment: .machine,
            cardioSecondaryUnit: .floors
        )
        let customDefinition = custom.toDefinition()
        let entry = TemplateEntry(
            exerciseDefinitionID: customDefinition.id,
            exerciseName: customDefinition.localizedName,
            equipment: customDefinition.equipment.rawValue
        )

        let resolved = TemplateExerciseResolver.resolveExercise(
            for: entry,
            library: ExerciseLibraryService(exercises: []),
            customExercises: [custom]
        )

        #expect(resolved?.id == customDefinition.id)
        #expect(resolved?.inputType == .durationDistance)
        #expect(resolved?.cardioSecondaryUnit == .floors)
    }

    @Test("profile identifies cardio entries from resolved custom exercise")
    func profileIdentifiesResolvedCustomCardio() {
        let custom = CustomExercise(
            name: "Machine Cardio",
            category: .cardio,
            inputType: .durationDistance,
            primaryMuscles: [.quadriceps],
            equipment: .machine,
            cardioSecondaryUnit: .timeOnly
        )
        let definition = custom.toDefinition()
        let entry = TemplateEntry(
            exerciseDefinitionID: definition.id,
            exerciseName: definition.localizedName,
            equipment: definition.equipment.rawValue
        )

        let profile = TemplateExerciseResolver.profile(
            for: entry,
            library: ExerciseLibraryService(exercises: []),
            customExercises: [custom]
        )

        #expect(profile == .cardio(.timeOnly))
        #expect(!profile.showsStrengthDefaultsEditor)
        #expect(profile.primarySummaryLabel == String(localized: "Duration"))
        #expect(profile.secondarySummaryLabel == nil)
    }

    @Test("profile falls back to persisted cardio metadata when exercise lookup fails")
    func profileFallsBackToPersistedCardioMetadata() {
        let entry = TemplateEntry(
            exerciseDefinitionID: "custom-missing-cardio",
            exerciseName: "Missing Cardio",
            inputTypeRaw: "duration",
            cardioSecondaryUnitRaw: CardioSecondaryUnit.floors.rawValue
        )

        let profile = TemplateExerciseResolver.profile(
            for: entry,
            library: ExerciseLibraryService(exercises: []),
            customExercises: []
        )

        #expect(profile == .cardio(.floors))
        #expect(!profile.showsStrengthDefaultsEditor)
        #expect(profile.primarySummaryLabel == String(localized: "Duration"))
        #expect(profile.secondarySummaryLabel == String(localized: "Floors"))
    }

    @Test("defaultEntry normalizes cardio templates to a single set")
    func defaultEntryNormalizesCardioTemplate() {
        let definition = makeCardioDefinition()

        let entry = TemplateExerciseResolver.defaultEntry(for: definition)

        #expect(entry.exerciseDefinitionID == definition.id)
        #expect(entry.defaultSets == 1)
        #expect(entry.defaultWeightKg == nil)
        #expect(entry.equipment == definition.equipment.rawValue)
        #expect(entry.inputTypeRaw == ExerciseInputType.durationDistance.rawValue)
        #expect(entry.cardioSecondaryUnitRaw == CardioSecondaryUnit.floors.rawValue)
    }

    @Test("resolveExercises restores recommended routines by canonical label order")
    func resolveRecommendedRoutineByCanonicalLabel() {
        let walking = ExerciseDefinition(
            id: "walking",
            name: "Walking",
            localizedName: "Walking",
            category: .cardio,
            inputType: .durationDistance,
            primaryMuscles: [.quadriceps],
            secondaryMuscles: [.calves],
            equipment: .bodyweight,
            metValue: 3.5,
            cardioSecondaryUnit: .km
        )
        let rowing = ExerciseDefinition(
            id: "rowing-machine",
            name: "Rowing Machine",
            localizedName: "Rowing Machine",
            category: .cardio,
            inputType: .durationDistance,
            primaryMuscles: [.back],
            secondaryMuscles: [.biceps],
            equipment: .machine,
            metValue: 7.0,
            cardioSecondaryUnit: .meters
        )
        let recommendation = WorkoutTemplateRecommendation(
            id: "walking>rowing",
            title: "Morning Walk + Row",
            sequenceTypes: [.walking, .rowing],
            sequenceLabels: ["Walking Recovery", "Rowing Machine"],
            frequency: 4,
            averageDurationMinutes: 18,
            lastPerformedAt: .now,
            score: 1.4
        )

        let resolved = TemplateExerciseResolver.resolveExercises(
            from: recommendation,
            library: ExerciseLibraryService(exercises: [walking, rowing])
        )

        #expect(resolved?.map { $0.id } == ["walking", "rowing-machine"])
    }

    @Test("resolveExercises returns nil instead of truncating unresolved recommendation steps")
    func resolveExercisesReturnsNilWhenSequenceCannotBeFullyResolved() {
        let walking = makeCardioDefinition(id: "walking", name: "Walking", cardioUnit: .km)
        let recommendation = WorkoutTemplateRecommendation(
            id: "walking>missing",
            title: "Incomplete Routine",
            sequenceTypes: [.walking, .rowing],
            sequenceLabels: ["Walking", "Unknown Row"],
            frequency: 2,
            averageDurationMinutes: 20,
            lastPerformedAt: .now,
            score: 1.1
        )

        let resolved = TemplateExerciseResolver.resolveExercises(
            from: recommendation,
            library: ExerciseLibraryService(exercises: [walking])
        )

        #expect(resolved == nil)
    }

    @Test("resolveExercises falls back to strength activity type for generic labels")
    func resolveExercisesFallsBackToStrengthActivityType() {
        let benchPress = makeStrengthDefinition()
        let recommendation = WorkoutTemplateRecommendation(
            id: "strength",
            title: "Strength Builder",
            sequenceTypes: [.traditionalStrengthTraining],
            sequenceLabels: ["Strength"],
            frequency: 3,
            averageDurationMinutes: 30,
            lastPerformedAt: .now,
            score: 1.0
        )

        let resolved = TemplateExerciseResolver.resolveExercises(
            from: recommendation,
            library: ExerciseLibraryService(exercises: [benchPress])
        )

        #expect(resolved?.map { $0.id } == ["bench-press"])
    }

    @Test("profile normalizes legacy raw cardio input aliases")
    func profileNormalizesLegacyCardioAlias() {
        let profile = TemplateExerciseProfile(
            inputTypeRaw: "duration",
            cardioSecondaryUnitRaw: CardioSecondaryUnit.floors.rawValue
        )

        #expect(profile == .cardio(.floors))
        #expect(!profile.showsStrengthDefaultsEditor)
    }
}
