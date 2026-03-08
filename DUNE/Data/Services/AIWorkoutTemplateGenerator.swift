import Foundation
import FoundationModels

struct AIWorkoutTemplateGenerator: NaturalLanguageWorkoutGenerating, Sendable {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    private let recommendationService: any WorkoutRecommending

    init(recommendationService: any WorkoutRecommending = WorkoutRecommendationService()) {
        self.recommendationService = recommendationService
    }

    var isAvailable: Bool {
        Self.isAvailable
    }

    func generateTemplate(
        from request: WorkoutTemplateGenerationRequest,
        library: ExerciseLibraryQuerying
    ) async throws -> GeneratedWorkoutTemplate {
        let trimmedPrompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw WorkoutTemplateGenerationError.emptyPrompt
        }
        guard Self.isAvailable else {
            throw WorkoutTemplateGenerationError.unavailable
        }

        do {
            let tool = SearchExerciseTool(library: library)
            let session = LanguageModelSession(
                tools: [tool],
                instructions: buildInstructions(localeIdentifier: request.localeIdentifier)
            )
            let response = try await session.respond(
                to: buildPrompt(
                    prompt: trimmedPrompt,
                    recentRecords: request.recentRecords,
                    library: library
                ),
                generating: AIWorkoutTemplate.self
            )
            return try resolveGeneratedTemplate(response.content, library: library)
        } catch let error as WorkoutTemplateGenerationError {
            throw error
        } catch {
            throw WorkoutTemplateGenerationError.generationFailed
        }
    }

    func buildInstructions(localeIdentifier: String) -> String {
        let languageCode = Locale(identifier: localeIdentifier).language.languageCode?.identifier ?? "en"

        switch languageCode {
        case "ko":
            return """
            당신은 DUNE 앱의 운동 템플릿 생성기입니다.
            재사용 가능한 운동 템플릿만 생성하세요.
            최종 구조화 응답을 만들기 전에 반드시 searchExercise 도구를 사용해 정확한 exerciseID와 exerciseName을 확인하세요.
            exerciseID와 exerciseName은 도구 결과를 그대로 복사하세요.
            템플릿 이름은 한국어로 작성하고, 운동 이름은 도구가 반환한 값을 그대로 사용하세요.
            세트/반복 수가 있는 strength 또는 bodyweight 운동을 우선 선택하세요.
            """
        case "ja":
            return """
            あなたはDUNEアプリのワークアウトテンプレート生成器です。
            再利用できるワークアウトテンプレートだけを作成してください。
            最終の構造化レスポンスを返す前に、必ず searchExercise ツールで正確な exerciseID と exerciseName を確認してください。
            exerciseID と exerciseName はツール結果をそのままコピーしてください。
            テンプレート名は日本語で書き、運動名はツールが返した値をそのまま使ってください。
            sets と reps に合う strength / bodyweight 種目を優先してください。
            """
        default:
            return """
            You generate reusable workout templates for the DUNE app.
            Before finalizing the structured response, always use the searchExercise tool to confirm the exact exerciseID and exerciseName.
            Copy exerciseID and exerciseName exactly from the tool result.
            Write the template name in the user's language, but keep exercise names exactly as returned by the tool.
            Prefer strength or bodyweight exercises that fit sets and reps.
            """
        }
    }

    func buildPrompt(
        prompt: String,
        recentRecords: [ExerciseRecordSnapshot],
        library: ExerciseLibraryQuerying
    ) -> String {
        var lines: [String] = []

        lines.append("User request:")
        lines.append(prompt)
        lines.append("")
        lines.append("Recent workout context:")
        lines.append(contentsOf: summarizeRecentHistory(recentRecords, library: library))
        lines.append("")
        lines.append("Template requirements:")
        lines.append("- Create a reusable workout template, not a one-off workout log.")
        lines.append("- Prefer 3 to 6 exercises unless the prompt clearly needs a different amount.")
        lines.append("- Keep estimatedMinutes aligned with the user's requested duration.")
        lines.append("- Avoid duplicate exercises.")
        lines.append("- Prefer recovered muscles when recent history suggests clear fatigue.")
        lines.append("- Choose exercises that work as template defaults with sets and reps.")
        lines.append("- Use only exercises that exist in DUNE's exercise catalog.")
        lines.append("- If there is not enough context, still generate a reasonable safe template.")

        return lines.joined(separator: "\n")
    }

    func summarizeRecentHistory(
        _ records: [ExerciseRecordSnapshot],
        library: ExerciseLibraryQuerying
    ) -> [String] {
        guard !records.isEmpty else {
            return ["- No recent workout history was provided."]
        }

        let recent = Array(records.sorted { $0.date > $1.date }.prefix(30))
        let twoWeeksAgo = Date().addingTimeInterval(-14 * 86_400)
        let lastTwoWeeks = recent.filter { $0.date >= twoWeeksAgo }

        var lines: [String] = []
        lines.append("- Recent workout count: \(lastTwoWeeks.count) in the last 14 days.")

        let topExercises = topRecentExercises(in: lastTwoWeeks, library: library)
        if !topExercises.isEmpty {
            lines.append("- Most frequent recent exercises: \(topExercises.joined(separator: ", ")).")
        }

        let fatigueStates = recommendationService.computeFatigueStates(
            from: recent,
            sleepModifier: 1.0,
            readinessModifier: 1.0
        )
        let recovered = fatigueStates
            .filter { $0.isRecovered && $0.weeklyVolume > 0 }
            .sorted { lhs, rhs in
                if lhs.recoveryPercent != rhs.recoveryPercent {
                    return lhs.recoveryPercent > rhs.recoveryPercent
                }
                return lhs.weeklyVolume < rhs.weeklyVolume
            }
            .prefix(3)
            .map { readableMuscleName($0.muscle) }
        if !recovered.isEmpty {
            lines.append("- Better recovered muscles: \(recovered.joined(separator: ", ")).")
        }

        let overworked = fatigueStates
            .filter(\.isOverworked)
            .sorted { $0.weeklyVolume > $1.weeklyVolume }
            .prefix(3)
            .map { readableMuscleName($0.muscle) }
        if !overworked.isEmpty {
            lines.append("- Recently overworked muscles to deprioritize when possible: \(overworked.joined(separator: ", ")).")
        }

        return lines
    }

    func topRecentExercises(
        in records: [ExerciseRecordSnapshot],
        library: ExerciseLibraryQuerying
    ) -> [String] {
        let counts = Dictionary(
            grouping: records.compactMap { snapshot -> String? in
                if let id = snapshot.exerciseDefinitionID,
                   let definition = library.exercise(byID: id) {
                    return definition.localizedName
                }
                return snapshot.exerciseName?.trimmingCharacters(in: .whitespacesAndNewlines)
            },
            by: { $0 }
        )

        return counts
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count {
                    return lhs.value.count > rhs.value.count
                }
                return lhs.key < rhs.key
            }
            .prefix(4)
            .map(\.key)
    }

    func resolveGeneratedTemplate(
        _ generated: AIWorkoutTemplate,
        library: ExerciseLibraryQuerying
    ) throws -> GeneratedWorkoutTemplate {
        let name = generated.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw WorkoutTemplateGenerationError.invalidTemplate
        }

        var seenIDs = Set<String>()
        let resolvedSlots = generated.exercises.compactMap { slot -> GeneratedWorkoutExerciseSlot? in
            guard let exercise = resolveExercise(
                exerciseID: slot.exerciseID,
                exerciseName: slot.exerciseName,
                library: library
            ) else {
                return nil
            }
            guard exercise.inputType == .setsRepsWeight || exercise.inputType == .setsReps else {
                return nil
            }
            guard seenIDs.insert(exercise.id).inserted else {
                return nil
            }

            return GeneratedWorkoutExerciseSlot(
                exerciseDefinitionID: exercise.id,
                exerciseName: exercise.localizedName,
                sets: slot.sets,
                reps: slot.reps
            )
        }

        guard !resolvedSlots.isEmpty else {
            throw WorkoutTemplateGenerationError.noExercisesMatched
        }

        return GeneratedWorkoutTemplate(
            name: name,
            estimatedMinutes: generated.estimatedMinutes,
            slots: resolvedSlots
        )
    }

    func resolveExercise(
        exerciseID: String,
        exerciseName: String,
        library: ExerciseLibraryQuerying
    ) -> ExerciseDefinition? {
        let trimmedID = exerciseID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedID.isEmpty,
           let byID = library.exercise(byID: trimmedID) {
            return byID
        }

        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return nil
        }

        let normalizedName = normalizedSearchText(trimmedName)
        let directMatches = library.search(query: trimmedName).filter { exercise in
            candidateLabels(for: exercise).contains(normalizedName)
        }
        if directMatches.count == 1, let exact = directMatches.first {
            return exact
        }

        let fuzzyMatches = library.search(query: trimmedName)
        guard fuzzyMatches.count == 1 else {
            return nil
        }
        return fuzzyMatches.first
    }

    func candidateLabels(for exercise: ExerciseDefinition) -> Set<String> {
        let rawValues = [exercise.name, exercise.localizedName] + (exercise.aliases ?? [])
        return Set(rawValues.map(normalizedSearchText).filter { !$0.isEmpty })
    }

    func normalizedSearchText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(
                of: #"[^\\p{L}\\p{N}\\s]"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func readableMuscleName(_ muscle: MuscleGroup) -> String {
        switch muscle {
        case .chest: "chest"
        case .back: "back"
        case .shoulders: "shoulders"
        case .biceps: "biceps"
        case .triceps: "triceps"
        case .quadriceps: "quads"
        case .hamstrings: "hamstrings"
        case .glutes: "glutes"
        case .calves: "calves"
        case .core: "core"
        case .forearms: "forearms"
        case .traps: "traps"
        case .lats: "lats"
        }
    }
}

extension AIWorkoutTemplateGenerator {
    struct SearchExerciseTool: Tool {
        @Generable(description: "Arguments for exercise catalog search")
        struct Arguments {
            @Guide(description: "A short exercise query such as shoulder press or push up")
            let query: String
        }

        let name = "searchExercise"
        let description = "Search the DUNE exercise catalog and return exact exercise IDs and names for strength or bodyweight template exercises."

        private let library: any ExerciseLibraryQuerying

        init(library: any ExerciseLibraryQuerying) {
            self.library = library
        }

        func call(arguments: Arguments) async throws -> String {
            let query = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                return "No query provided."
            }

            let matches = library.search(query: query)
                .filter { $0.inputType == .setsRepsWeight || $0.inputType == .setsReps }
            guard !matches.isEmpty else {
                return "No matching strength or bodyweight exercises were found."
            }

            return matches
                .prefix(8)
                .map { exercise in
                    let muscles = (exercise.primaryMuscles + exercise.secondaryMuscles)
                        .map(\.rawValue)
                        .joined(separator: ", ")
                    return "- id: \(exercise.id) | name: \(exercise.localizedName) | category: \(exercise.category.rawValue) | muscles: \(muscles) | equipment: \(exercise.equipment.rawValue) | input: \(exercise.inputType.rawValue)"
                }
                .joined(separator: "\n")
        }
    }
}

@Generable(description: "A reusable workout template for the DUNE app")
struct AIWorkoutTemplate {
    @Guide(description: "Short workout template name in the user's language")
    let name: String

    @Guide(.count(1...8))
    @Guide(description: "Ordered exercise slots for the workout template")
    let exercises: [AIExerciseSlot]

    @Guide(description: "Estimated total workout time in minutes")
    @Guide(.range(10...120))
    let estimatedMinutes: Int
}

@Generable(description: "A single exercise slot inside a generated workout template")
struct AIExerciseSlot {
    @Guide(description: "Exact exercise ID copied from the searchExercise tool result")
    let exerciseID: String

    @Guide(description: "Exact exercise name copied from the searchExercise tool result")
    let exerciseName: String

    @Guide(description: "Suggested number of sets")
    @Guide(.range(1...10))
    let sets: Int

    @Guide(description: "Suggested number of reps per set")
    @Guide(.range(1...30))
    let reps: Int
}
