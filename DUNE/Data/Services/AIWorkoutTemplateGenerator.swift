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
        let promptIntent = Self.promptIntent(for: trimmedPrompt)
        if let preflightError = Self.preflightError(for: promptIntent) {
            throw preflightError
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
                    library: library,
                    promptIntent: promptIntent
                ),
                generating: AIWorkoutTemplate.self
            )
            let generated = response.content
            AppLogger.exercise.debug(
                "AI workout template raw output promptHash=\(trimmedPrompt, privacy: .private(mask: .hash)) name=\(generated.name, privacy: .private) estimated=\(generated.estimatedMinutes, privacy: .public) slotCount=\(generated.exercises.count, privacy: .public) slots=\(debugSlotSummary(generated.exercises), privacy: .private)"
            )
            return try resolveGeneratedTemplate(generated, library: library)
        } catch let error as WorkoutTemplateGenerationError {
            AppLogger.exercise.error(
                "AI workout template typed failure promptHash=\(trimmedPrompt, privacy: .private(mask: .hash)) error=\(String(describing: error), privacy: .private)"
            )
            throw error
        } catch {
            AppLogger.exercise.error(
                "AI workout template generation failed promptHash=\(trimmedPrompt, privacy: .private(mask: .hash)) error=\(String(describing: error), privacy: .private)"
            )
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
            사용자의 요청이 넓은 자연어 문장이라면 그대로 한 번에 검색하지 말고, 부위/장비/운동 카테고리 핵심어로 나누어 searchExercise를 여러 번 호출하세요.
            예: "어깨 운동 만들어줘" -> "어깨", "숄더", "덤벨 어깨".
            strength/bodyweight 운동을 우선 선택하되, 사용자가 달리기/걷기/사이클 같은 cardio를 요청하면 cardio/time-based 운동도 포함할 수 있습니다.
            cardio 또는 time-based 운동은 sets = 1, reps = 1 로 반환하세요.
            """
        case "ja":
            return """
            あなたはDUNEアプリのワークアウトテンプレート生成器です。
            再利用できるワークアウトテンプレートだけを作成してください。
            最終の構造化レスポンスを返す前に、必ず searchExercise ツールで正確な exerciseID と exerciseName を確認してください。
            exerciseID と exerciseName はツール結果をそのままコピーしてください。
            テンプレート名は日本語で書き、運動名はツールが返した値をそのまま使ってください。
            リクエストが広い自然文なら、そのまま全文検索せず、部位・器具・運動カテゴリの短い概念に分けて searchExercise を複数回使ってください。
            strength / bodyweight 種目を優先しつつ、ランニングやウォーキングなど cardio 指定がある場合は cardio / time-based 種目も使えます。
            cardio / time-based 種目は sets = 1, reps = 1 を返してください。
            """
        default:
            return """
            You generate reusable workout templates for the DUNE app.
            Before finalizing the structured response, always use the searchExercise tool to confirm the exact exerciseID and exerciseName.
            Copy exerciseID and exerciseName exactly from the tool result.
            Write the template name in the user's language, but keep exercise names exactly as returned by the tool.
            If the request is a broad natural-language sentence, do not search the whole sentence verbatim. Break it into short concepts like body part, equipment, or workout category and call searchExercise multiple times.
            Prefer strength or bodyweight exercises, but include cardio or time-based exercises when the user asks for them.
            For cardio or time-based exercises, return sets = 1 and reps = 1.
            """
        }
    }

    func buildPrompt(
        prompt: String,
        recentRecords: [ExerciseRecordSnapshot],
        library: ExerciseLibraryQuerying,
        promptIntent: WorkoutPromptIntent
    ) -> String {
        var lines: [String] = []

        lines.append("User request:")
        lines.append(prompt)
        lines.append("")
        let promptHints = Self.promptSummaryLines(for: promptIntent)
        if !promptHints.isEmpty {
            lines.append("Interpreted request hints:")
            lines.append(contentsOf: promptHints)
            lines.append("")
        }
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
        lines.append("- Cardio or time-based exercises are allowed when they fit the request.")
        lines.append("- For cardio or time-based exercises, use sets = 1 and reps = 1.")
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
        var resolvedSlots: [GeneratedWorkoutExerciseSlot] = []

        for slot in generated.exercises {
            guard let exercise = resolveExercise(
                exerciseID: slot.exerciseID,
                exerciseName: slot.exerciseName,
                library: library
            ) else {
                AppLogger.exercise.debug(
                    "AI workout template dropped unresolved slot id=\(slot.exerciseID, privacy: .private) name=\(slot.exerciseName, privacy: .private)"
                )
                continue
            }
            guard Self.isTemplateSupported(exercise) else {
                AppLogger.exercise.debug(
                    "AI workout template dropped unsupported slot resolvedID=\(exercise.id, privacy: .private) inputType=\(exercise.inputType.rawValue, privacy: .public)"
                )
                continue
            }
            guard seenIDs.insert(exercise.id).inserted else {
                AppLogger.exercise.debug(
                    "AI workout template dropped duplicate slot resolvedID=\(exercise.id, privacy: .private)"
                )
                continue
            }

            switch exercise.inputType {
            case .durationDistance:
                resolvedSlots.append(
                    GeneratedWorkoutExerciseSlot(
                        exerciseDefinitionID: exercise.id,
                        exerciseName: exercise.localizedName,
                        sets: 1,
                        reps: 1
                    )
                )
            case .setsRepsWeight, .setsReps:
                resolvedSlots.append(
                    GeneratedWorkoutExerciseSlot(
                        exerciseDefinitionID: exercise.id,
                        exerciseName: exercise.localizedName,
                        sets: slot.sets,
                        reps: slot.reps
                    )
                )
            case .durationIntensity, .roundsBased:
                AppLogger.exercise.debug(
                    "AI workout template dropped post-filter unsupported slot resolvedID=\(exercise.id, privacy: .private) inputType=\(exercise.inputType.rawValue, privacy: .public)"
                )
            }
        }

        guard !resolvedSlots.isEmpty else {
            AppLogger.exercise.error(
                "AI workout template matched no exercises name=\(name, privacy: .private) rawSlotCount=\(generated.exercises.count, privacy: .public) rawSlots=\(debugSlotSummary(generated.exercises), privacy: .private)"
            )
            throw WorkoutTemplateGenerationError.noExercisesMatched
        }

        AppLogger.exercise.debug(
            "AI workout template resolved name=\(name, privacy: .private) resolvedSlotCount=\(resolvedSlots.count, privacy: .public) resolvedSlots=\(debugResolvedSlotSummary(resolvedSlots), privacy: .private)"
        )

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
        let directMatches = Self.searchMatches(for: trimmedName, library: library).filter { exercise in
            candidateLabels(for: exercise).contains(normalizedName)
        }
        if directMatches.count == 1, let exact = directMatches.first {
            return exact
        }
        if directMatches.count > 1 {
            AppLogger.exercise.debug(
                "AI workout template ambiguous exact lookup name=\(trimmedName, privacy: .private) matchCount=\(directMatches.count, privacy: .public) matches=\(directMatches.map(\.id).joined(separator: ", "), privacy: .private)"
            )
        }

        let fuzzyMatches = Self.searchMatches(for: trimmedName, library: library)
        guard fuzzyMatches.count == 1 else {
            AppLogger.exercise.debug(
                "AI workout template fuzzy lookup failed name=\(trimmedName, privacy: .private) matchCount=\(fuzzyMatches.count, privacy: .public) matches=\(fuzzyMatches.prefix(8).map(\.id).joined(separator: ", "), privacy: .private)"
            )
            return nil
        }
        return fuzzyMatches.first
    }

    func candidateLabels(for exercise: ExerciseDefinition) -> Set<String> {
        Self.candidateLabels(for: exercise)
    }

    static func isTemplateSupported(_ exercise: ExerciseDefinition) -> Bool {
        switch exercise.inputType {
        case .setsRepsWeight, .setsReps, .durationDistance:
            true
        case .durationIntensity, .roundsBased:
            false
        }
    }

    func normalizedSearchText(_ text: String) -> String {
        Self.normalizedSearchText(text)
    }

    static func normalizedSearchText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(
                of: #"[^\\p{L}\\p{N}\\s]"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func candidateLabels(for exercise: ExerciseDefinition) -> Set<String> {
        let rawValues = [exercise.name, exercise.localizedName] + (exercise.aliases ?? [])
        return Set(rawValues.map(normalizedSearchText).filter { !$0.isEmpty })
    }

    static func promptIntent(for query: String) -> WorkoutPromptIntent {
        let normalizedQuery = normalizedSearchText(query)
        let strippedQuery = strippedPromptQuery(normalizedQuery)

        var muscleTargets = Set<MuscleGroup>()
        var preferredEquipment = Set<Equipment>()
        var preferredCategories = Set<ExerciseCategory>()
        var matchedSearchTerms = Set<String>()

        for (keyword, muscles) in muscleKeywordMap where normalizedQuery.contains(keyword) {
            muscleTargets.formUnion(muscles)
            matchedSearchTerms.insert(keyword)
        }

        for (keyword, equipment) in equipmentKeywordMap where normalizedQuery.contains(keyword) {
            preferredEquipment.formUnion(equipment)
            matchedSearchTerms.insert(keyword)
        }

        if normalizedQuery.contains("맨몸") || normalizedQuery.contains("bodyweight") {
            preferredCategories.insert(.bodyweight)
        }
        if muscleTargets.isEmpty {
            for (keyword, categories) in categoryKeywordMap where normalizedQuery.contains(keyword) {
                preferredCategories.formUnion(categories)
                matchedSearchTerms.insert(keyword)
            }
        }

        let requestsHomeFriendlySelection = homeKeywords.contains { normalizedQuery.contains($0) }
        let requestedMinutes = requestedDurationMinutes(in: normalizedQuery)
        let meaningfulCore = strippedQuery.replacingOccurrences(
            of: #"\d+\s*(분|시간|min|mins|minute|minutes|hr|hrs|hour|hours)"#,
            with: " ",
            options: .regularExpression
        )
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let isUnsupportedRequest =
            unsupportedOnlyKeywords.contains { normalizedQuery.contains($0) }
            && muscleTargets.isEmpty
            && preferredEquipment.isEmpty
            && preferredCategories.isEmpty

        let isAmbiguousRequest =
            !isUnsupportedRequest
            && muscleTargets.isEmpty
            && preferredEquipment.isEmpty
            && preferredCategories.isEmpty
            && (meaningfulCore.isEmpty || genericPromptQualifiers.contains(meaningfulCore))

        if !strippedQuery.isEmpty {
            matchedSearchTerms.insert(strippedQuery)
        }

        return WorkoutPromptIntent(
            normalizedQuery: normalizedQuery,
            strippedQuery: strippedQuery,
            muscleTargets: muscleTargets,
            preferredEquipment: preferredEquipment,
            preferredCategories: preferredCategories,
            matchedSearchTerms: matchedSearchTerms,
            requestsHomeFriendlySelection: requestsHomeFriendlySelection,
            requestedMinutes: requestedMinutes,
            isUnsupportedRequest: isUnsupportedRequest,
            isAmbiguousRequest: isAmbiguousRequest
        )
    }

    static func preflightError(for intent: WorkoutPromptIntent) -> WorkoutTemplateGenerationError? {
        if intent.isUnsupportedRequest {
            return .unsupportedRequest
        }
        if intent.isAmbiguousRequest {
            return .ambiguousPrompt
        }
        return nil
    }

    static func promptSummaryLines(for intent: WorkoutPromptIntent) -> [String] {
        var lines: [String] = []

        if !intent.muscleTargets.isEmpty {
            let muscles = intent.muscleTargets.map(\.rawValue).sorted().joined(separator: ", ")
            lines.append("- Requested muscles: \(muscles).")
        }
        if !intent.preferredEquipment.isEmpty {
            let equipment = intent.preferredEquipment.map(\.rawValue).sorted().joined(separator: ", ")
            lines.append("- Preferred equipment: \(equipment).")
        }
        if !intent.preferredCategories.isEmpty {
            let categories = intent.preferredCategories.map(\.rawValue).sorted().joined(separator: ", ")
            lines.append("- Preferred categories: \(categories).")
        }
        if intent.requestsHomeFriendlySelection {
            lines.append("- Prefer home-friendly exercise options when possible.")
        }
        if let requestedMinutes = intent.requestedMinutes {
            lines.append("- Requested duration: \(requestedMinutes) minutes.")
        }

        return lines
    }

    static func searchMatches(
        for query: String,
        library: any ExerciseLibraryQuerying
    ) -> [ExerciseDefinition] {
        let intent = promptIntent(for: query)
        let allTemplateExercises = library.allExercises().filter(isTemplateSupported)
        var candidateByID: [String: ExerciseDefinition] = [:]

        func add(_ exercises: [ExerciseDefinition]) {
            for exercise in exercises where isTemplateSupported(exercise) {
                candidateByID[exercise.id] = exercise
            }
        }

        add(library.search(query: query))
        for term in intent.matchedSearchTerms where !term.isEmpty {
            add(library.search(query: term))
        }
        for muscle in intent.muscleTargets {
            add(library.exercises(forMuscle: muscle))
        }
        for category in intent.preferredCategories {
            add(library.exercises(forCategory: category))
        }

        if intent.requestsHomeFriendlySelection || !intent.preferredEquipment.isEmpty {
            add(allTemplateExercises.filter { matchesEquipmentIntent($0, intent: intent) })
        }

        if candidateByID.isEmpty {
            add(allTemplateExercises)
        }

        var scoredMatches = candidateByID.values
            .map { ($0, searchScore(for: $0, intent: intent)) }
            .filter { $0.1 > 0 }

        if intent.requestsHomeFriendlySelection,
           scoredMatches.contains(where: { homeFriendlyEquipment.contains($0.0.equipment) }) {
            scoredMatches = scoredMatches.filter { homeFriendlyEquipment.contains($0.0.equipment) }
        }

        if !intent.preferredEquipment.isEmpty,
           scoredMatches.contains(where: { matchesPreferredEquipment($0.0, preferredEquipment: intent.preferredEquipment) }) {
            scoredMatches = scoredMatches.filter {
                matchesPreferredEquipment($0.0, preferredEquipment: intent.preferredEquipment)
            }
        }

        return scoredMatches
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                return lhs.0.localizedName.localizedCaseInsensitiveCompare(rhs.0.localizedName) == .orderedAscending
            }
            .map(\.0)
    }

    static func searchScore(
        for exercise: ExerciseDefinition,
        intent: WorkoutPromptIntent
    ) -> Int {
        let phrases = intent.matchedSearchTerms.union([intent.normalizedQuery]).filter { !$0.isEmpty }
        let labelScore = candidateLabels(for: exercise)
            .flatMap { label in
                phrases.map { phrase in scoreForMatch(query: phrase, against: label) }
            }
            .max() ?? 0

        let primaryMatches = Set(exercise.primaryMuscles).intersection(intent.muscleTargets).count
        let secondaryMatches = Set(exercise.secondaryMuscles).intersection(intent.muscleTargets).count
        let muscleScore = primaryMatches * 260 + secondaryMatches * 140

        let categoryScore: Int
        if intent.preferredCategories.isEmpty {
            categoryScore = 0
        } else if intent.preferredCategories.contains(exercise.category) {
            categoryScore = 220
        } else {
            categoryScore = -80
        }

        let equipmentScore: Int
        if intent.preferredEquipment.isEmpty {
            equipmentScore = 0
        } else if matchesPreferredEquipment(exercise, preferredEquipment: intent.preferredEquipment) {
            equipmentScore = 220
        } else {
            equipmentScore = -260
        }

        let homeScore: Int
        if intent.requestsHomeFriendlySelection {
            homeScore = homeFriendlyEquipment.contains(exercise.equipment) ? 160 : -180
        } else {
            homeScore = 0
        }

        let bodyweightBonus =
            intent.preferredCategories.contains(.bodyweight) && exercise.equipment == .bodyweight ? 80 : 0

        return labelScore + muscleScore + categoryScore + equipmentScore + homeScore + bodyweightBonus
    }

    static func scoreForMatch(query: String, against label: String) -> Int {
        guard !label.isEmpty, !query.isEmpty else { return 0 }
        if label == query {
            return 1_000 + label.count
        }
        if label.contains(query) {
            return 820 + query.count
        }
        if query.contains(label) {
            return 720 + label.count
        }

        let queryTokens = Set(query.split(separator: " ").map(String.init))
        let labelTokens = Set(label.split(separator: " ").map(String.init))

        if !queryTokens.isEmpty, queryTokens.isSubset(of: labelTokens) {
            return 620 + queryTokens.count * 10
        }
        if !labelTokens.isEmpty, labelTokens.isSubset(of: queryTokens) {
            return 520 + labelTokens.count * 10
        }

        let overlap = queryTokens.intersection(labelTokens).count
        if overlap > 0 {
            return 320 + overlap * 12
        }

        return 0
    }

    static func strippedPromptQuery(_ normalizedQuery: String) -> String {
        let stripped = promptFillerPhrases.reduce(normalizedQuery) { partial, filler in
            partial.replacingOccurrences(of: filler, with: " ")
        }

        return stripped
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func requestedDurationMinutes(in normalizedQuery: String) -> Int? {
        let pattern = #"(?<!\d)(\d{1,3})\s*(분|시간|min|mins|minute|minutes|hr|hrs|hour|hours)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: normalizedQuery,
                range: NSRange(normalizedQuery.startIndex..<normalizedQuery.endIndex, in: normalizedQuery)
              ),
              let valueRange = Range(match.range(at: 1), in: normalizedQuery),
              let unitRange = Range(match.range(at: 2), in: normalizedQuery),
              let rawValue = Int(normalizedQuery[valueRange])
        else {
            return nil
        }

        let unit = String(normalizedQuery[unitRange])
        switch unit {
        case "시간", "hr", "hrs", "hour", "hours":
            return rawValue * 60
        default:
            return rawValue
        }
    }

    static func matchesPreferredEquipment(
        _ exercise: ExerciseDefinition,
        preferredEquipment: Set<Equipment>
    ) -> Bool {
        preferredEquipment.contains { preferred in
            preferred.compatibleLibraryValues.contains(exercise.equipment)
                || exercise.equipment.compatibleLibraryValues.contains(preferred)
        }
    }

    static func matchesEquipmentIntent(
        _ exercise: ExerciseDefinition,
        intent: WorkoutPromptIntent
    ) -> Bool {
        if intent.requestsHomeFriendlySelection && !homeFriendlyEquipment.contains(exercise.equipment) {
            return false
        }
        if intent.preferredEquipment.isEmpty {
            return true
        }
        return matchesPreferredEquipment(exercise, preferredEquipment: intent.preferredEquipment)
    }

    static let promptFillerPhrases: [String] = [
        "운동",
        "루틴",
        "템플릿",
        "만들어줘",
        "만들어 줘",
        "만들어",
        "추천해줘",
        "추천해 줘",
        "추천",
        "해줘",
        "해 줘",
        "build me",
        "make me",
        "build",
        "make",
        "workout",
        "routine",
        "template",
        "please",
    ]

    static let genericPromptQualifiers: Set<String> = [
        "좋은",
        "good",
        "best",
        "무난한",
        "운동 추천",
    ]

    static let unsupportedOnlyKeywords: Set<String> = [
        "mobility",
        "stretch",
        "stretching",
        "flexibility",
        "yoga",
        "pilates",
        "burpee",
        "burpees",
        "스트레칭",
        "모빌리티",
        "유연성",
        "요가",
        "필라테스",
        "hiit",
        "circuit",
        "interval",
        "tabata",
        "버피",
        "서킷",
        "인터벌",
        "타바타",
    ]

    static let homeKeywords: Set<String> = [
        "집에서",
        "home",
        "홈트",
    ]

    static let homeFriendlyEquipment: Set<Equipment> = [
        .bodyweight,
        .dumbbell,
        .kettlebell,
        .band,
        .trx,
        .medicineBall,
        .stabilityBall,
        .pullUpBar,
        .dipStation,
    ]

    static let fullBodyMuscles: Set<MuscleGroup> =
        Set([.chest, .back, .lats, .shoulders, .biceps, .triceps, .quadriceps, .hamstrings, .glutes, .calves, .core])

    static let muscleKeywordMap: [(String, Set<MuscleGroup>)] = [
        ("어깨", [.shoulders, .traps]),
        ("숄더", [.shoulders, .traps]),
        ("shoulder", [.shoulders, .traps]),
        ("가슴", [.chest]),
        ("chest", [.chest]),
        ("등", [.back, .lats, .traps]),
        ("back", [.back, .lats]),
        ("랫", [.lats, .back]),
        ("lat", [.lats, .back]),
        ("코어", [.core]),
        ("복근", [.core]),
        ("core", [.core]),
        ("이두", [.biceps]),
        ("biceps", [.biceps]),
        ("삼두", [.triceps]),
        ("triceps", [.triceps]),
        ("하체", [.quadriceps, .hamstrings, .glutes, .calves]),
        ("lower body", [.quadriceps, .hamstrings, .glutes, .calves]),
        ("상체", [.chest, .back, .lats, .shoulders, .biceps, .triceps]),
        ("upper body", [.chest, .back, .lats, .shoulders, .biceps, .triceps]),
        ("전신", fullBodyMuscles),
        ("full body", fullBodyMuscles),
        ("풀바디", fullBodyMuscles),
    ]

    static let equipmentKeywordMap: [(String, Set<Equipment>)] = [
        ("맨몸", [.bodyweight]),
        ("bodyweight", [.bodyweight]),
        ("덤벨", [.dumbbell]),
        ("dumbbell", [.dumbbell]),
        ("바벨", [.barbell]),
        ("barbell", [.barbell]),
        ("케틀벨", [.kettlebell]),
        ("kettlebell", [.kettlebell]),
        ("밴드", [.band]),
        ("band", [.band]),
        ("trx", [.trx]),
        ("머신", [.machine]),
        ("machine", [.machine]),
        ("케이블", [.cable, .cableMachine]),
        ("cable", [.cable, .cableMachine]),
    ]

    static let categoryKeywordMap: [(String, Set<ExerciseCategory>)] = [
        ("러닝", [.cardio]),
        ("달리기", [.cardio]),
        ("running", [.cardio]),
        ("조깅", [.cardio]),
        ("걷기", [.cardio]),
        ("walking", [.cardio]),
        ("산책", [.cardio]),
        ("사이클", [.cardio]),
        ("사이클링", [.cardio]),
        ("cycling", [.cardio]),
        ("bike", [.cardio]),
        ("cardio", [.cardio]),
        ("유산소", [.cardio]),
    ]

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

    func debugSlotSummary(_ slots: [AIExerciseSlot]) -> String {
        slots.map { slot in
            "[id=\(slot.exerciseID), name=\(slot.exerciseName), sets=\(slot.sets), reps=\(slot.reps)]"
        }
        .joined(separator: ", ")
    }

    func debugResolvedSlotSummary(_ slots: [GeneratedWorkoutExerciseSlot]) -> String {
        slots.map { slot in
            "[id=\(slot.exerciseDefinitionID), name=\(slot.exerciseName), sets=\(slot.sets), reps=\(slot.reps)]"
        }
        .joined(separator: ", ")
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
        let description = "Search the DUNE exercise catalog and return exact exercise IDs and names for template-capable exercises, including cardio."

        private let library: any ExerciseLibraryQuerying

        init(library: any ExerciseLibraryQuerying) {
            self.library = library
        }

        func call(arguments: Arguments) async throws -> String {
            let query = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                return "No query provided."
            }

            let intent = AIWorkoutTemplateGenerator.promptIntent(for: query)
            if let preflightError = AIWorkoutTemplateGenerator.preflightError(for: intent) {
                switch preflightError {
                case .unsupportedRequest:
                    return "This request focuses on workout styles that the template builder cannot save yet."
                case .ambiguousPrompt:
                    return "The request is too broad. Add a body part, time, or equipment."
                default:
                    break
                }
            }

            let matches = AIWorkoutTemplateGenerator.searchMatches(for: query, library: library)
            guard !matches.isEmpty else {
                return "No matching template-capable exercises were found."
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

struct WorkoutPromptIntent: Sendable {
    let normalizedQuery: String
    let strippedQuery: String
    let muscleTargets: Set<MuscleGroup>
    let preferredEquipment: Set<Equipment>
    let preferredCategories: Set<ExerciseCategory>
    let matchedSearchTerms: Set<String>
    let requestsHomeFriendlySelection: Bool
    let requestedMinutes: Int?
    let isUnsupportedRequest: Bool
    let isAmbiguousRequest: Bool
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
