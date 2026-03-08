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
        let defaultReps = switch profile {
        case .cardio:
            1
        case .strengthLike, .unresolved:
            10
        }

        return TemplateEntry(
            exerciseDefinitionID: exercise.id,
            exerciseName: exercise.localizedName,
            defaultSets: defaultSets,
            defaultReps: defaultReps,
            equipment: exercise.equipment.rawValue,
            inputTypeRaw: exercise.inputType.rawValue,
            cardioSecondaryUnitRaw: exercise.cardioSecondaryUnit?.rawValue
        )
    }

    static func resolveExercises(
        from recommendation: WorkoutTemplateRecommendation,
        library: ExerciseLibraryQuerying
    ) -> [ExerciseDefinition]? {
        guard recommendation.sequenceLabels.count == recommendation.sequenceTypes.count else {
            return nil
        }

        let exercises = library.allExercises()
        var resolved: [ExerciseDefinition] = []
        resolved.reserveCapacity(recommendation.sequenceLabels.count)

        for (label, activityType) in zip(recommendation.sequenceLabels, recommendation.sequenceTypes) {
            guard let exercise = resolveRecommendedExercise(
                label: label,
                activityType: activityType,
                exercises: exercises
            ) else {
                return nil
            }
            resolved.append(exercise)
        }

        return resolved
    }

    private static func resolveRecommendedExercise(
        label: String,
        activityType: WorkoutActivityType,
        exercises: [ExerciseDefinition]
    ) -> ExerciseDefinition? {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonicalLabel = QuickStartCanonicalService.canonicalExerciseName(for: trimmedLabel)

        if !canonicalLabel.isEmpty {
            let exactMatches = exercises.filter {
                recommendationLookupKeys(for: $0).contains(canonicalLabel)
            }

            if let exactMatch = preferredRecommendationMatch(
                in: exactMatches,
                activityType: activityType
            ) {
                return exactMatch
            }
        }

        let canonicalTypeName = QuickStartCanonicalService.canonicalExerciseName(for: activityType.typeName)
        guard !canonicalTypeName.isEmpty,
              canonicalLabel.isEmpty || canonicalLabel == canonicalTypeName else {
            return nil
        }

        let fallbackMatches = exercises.filter { $0.resolvedActivityType == activityType }
        return preferredRecommendationMatch(in: fallbackMatches, activityType: activityType)
    }

    private static func recommendationLookupKeys(for exercise: ExerciseDefinition) -> Set<String> {
        let rawValues = [exercise.name, exercise.localizedName] + (exercise.aliases ?? [])
        return Set(rawValues.compactMap { rawValue in
            let canonical = QuickStartCanonicalService.canonicalExerciseName(for: rawValue)
            return canonical.isEmpty ? nil : canonical
        })
    }

    private static func preferredRecommendationMatch(
        in exercises: [ExerciseDefinition],
        activityType: WorkoutActivityType
    ) -> ExerciseDefinition? {
        exercises.min {
            recommendationSortKey(for: $0, activityType: activityType)
                < recommendationSortKey(for: $1, activityType: activityType)
        }
    }

    private static func recommendationSortKey(
        for exercise: ExerciseDefinition,
        activityType: WorkoutActivityType
    ) -> (Int, Int, String) {
        (
            exercise.resolvedActivityType == activityType ? 0 : 1,
            exercise.id.count,
            exercise.id
        )
    }
}
