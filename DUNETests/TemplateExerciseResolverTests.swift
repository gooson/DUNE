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
