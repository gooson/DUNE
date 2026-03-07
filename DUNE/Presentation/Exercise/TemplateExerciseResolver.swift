import Foundation

enum TemplateExerciseResolver {
    static func resolveExercise(
        for entry: TemplateEntry,
        library: ExerciseLibraryQuerying,
        customExercises: [CustomExercise]
    ) -> ExerciseDefinition? {
        if let definition = library.exercise(byID: entry.exerciseDefinitionID) {
            return definition
        }

        guard entry.exerciseDefinitionID.hasPrefix("custom-") else { return nil }

        return customExercises.first {
            "custom-\($0.id.uuidString)" == entry.exerciseDefinitionID
        }?.toDefinition()
    }

    static func profile(
        for entry: TemplateEntry,
        library: ExerciseLibraryQuerying,
        customExercises: [CustomExercise]
    ) -> TemplateExerciseProfile {
        if let exercise = resolveExercise(
            for: entry,
            library: library,
            customExercises: customExercises
        ) {
            return TemplateExerciseProfile(exercise: exercise)
        }

        return TemplateExerciseProfile(
            inputTypeRaw: entry.inputTypeRaw,
            cardioSecondaryUnitRaw: entry.cardioSecondaryUnitRaw
        )
    }

    static func entryWithResolvedMetadata(
        from entry: TemplateEntry,
        library: ExerciseLibraryQuerying,
        customExercises: [CustomExercise]
    ) -> TemplateEntry {
        var resolvedEntry = entry
        if let exercise = resolveExercise(
            for: entry,
            library: library,
            customExercises: customExercises
        ) {
            resolvedEntry.applyExerciseMetadata(from: exercise)
        } else {
            resolvedEntry.normalizeStoredMetadata()
        }
        return resolvedEntry
    }

    static func defaultEntry(for exercise: ExerciseDefinition) -> TemplateEntry {
        let profile = TemplateExerciseProfile(exercise: exercise)
        let defaultSets = switch profile {
        case .cardio:
            1
        case .strengthLike, .unresolved:
            3
        }

        return TemplateEntry(
            exerciseDefinitionID: exercise.id,
            exerciseName: exercise.localizedName,
            defaultSets: defaultSets,
            equipment: exercise.equipment.rawValue,
            inputTypeRaw: exercise.inputType.rawValue,
            cardioSecondaryUnitRaw: exercise.cardioSecondaryUnit?.rawValue
        )
    }
}
