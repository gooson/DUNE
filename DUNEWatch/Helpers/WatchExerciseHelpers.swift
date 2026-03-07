import Foundation

// MARK: - Shared Exercise Helpers
// Used by CarouselHomeView and QuickStartAllExercisesView.
// Extracted per Correction #37/#167 to prevent drift between copies.

/// Builds subtitle: "3 sets · 10 reps" or "3 sets · 10 reps · 80.0kg"
func exerciseSubtitle(sets: Int, reps: Int, weight: Double?) -> String {
    var parts = "\(sets) sets · \(reps) reps"
    if let w = weight, w > 0, w <= 500 {
        parts += " · \(w.formattedWeight)kg"
    }
    return parts
}

/// Deduplicates exercises by canonical ID, keeping first occurrence.
func uniqueByCanonical(_ exercises: [WatchExerciseInfo]) -> [WatchExerciseInfo] {
    var seen = Set<String>()
    return exercises.filter { exercise in
        let canonical = RecentExerciseTracker.canonicalExerciseID(exerciseID: exercise.id)
        return seen.insert(canonical).inserted
    }
}

func recentWatchExercises(
    from exercises: [WatchExerciseInfo],
    limit: Int,
    lastUsedTimestamps: [String: Double] = RecentExerciseTracker.lastUsedTimestamps()
) -> [WatchExerciseInfo] {
    guard limit > 0 else { return [] }

    return Array(
        uniqueByCanonical(
            exercises
                .filter { lastUsedTimestamps[$0.id] != nil }
                .sorted {
                    let lhs = lastUsedTimestamps[$0.id] ?? Date.distantPast.timeIntervalSince1970
                    let rhs = lastUsedTimestamps[$1.id] ?? Date.distantPast.timeIntervalSince1970
                    return lhs > rhs
                }
        )
        .prefix(limit)
    )
}

func preferredWatchExercises(
    from exercises: [WatchExerciseInfo],
    excludingCanonical excludedCanonical: Set<String> = [],
    lastUsedTimestamps: [String: Double] = RecentExerciseTracker.lastUsedTimestamps()
) -> [WatchExerciseInfo] {
    uniqueByCanonical(
        exercises
            .filter { $0.isPreferred }
            .sorted { lhs, rhs in
                let lhsTime = lastUsedTimestamps[lhs.id] ?? Date.distantPast.timeIntervalSince1970
                let rhsTime = lastUsedTimestamps[rhs.id] ?? Date.distantPast.timeIntervalSince1970
                if lhsTime != rhsTime { return lhsTime > rhsTime }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    )
    .filter { exercise in
        !excludedCanonical.contains(RecentExerciseTracker.canonicalExerciseID(exerciseID: exercise.id))
    }
}

func popularWatchExercises(
    from exercises: [WatchExerciseInfo],
    limit: Int,
    excludingCanonical excludedCanonical: Set<String> = []
) -> [WatchExerciseInfo] {
    guard limit > 0 else { return [] }

    return Array(
        uniqueByCanonical(
            RecentExerciseTracker.personalizedPopular(from: exercises, limit: limit)
        )
        .filter { exercise in
            !excludedCanonical.contains(RecentExerciseTracker.canonicalExerciseID(exerciseID: exercise.id))
        }
        .prefix(limit)
    )
}

func prioritizedWatchExercises(
    _ exercises: [WatchExerciseInfo],
    recent: [WatchExerciseInfo],
    preferred: [WatchExerciseInfo],
    popular: [WatchExerciseInfo]
) -> [WatchExerciseInfo] {
    let orderedCanonicalIDs = (recent + preferred + popular).map {
        RecentExerciseTracker.canonicalExerciseID(exerciseID: $0.id)
    }
    let priorityByCanonicalID = Dictionary(
        orderedCanonicalIDs.enumerated().map { ($1, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    return exercises.sorted { lhs, rhs in
        let lhsKey = RecentExerciseTracker.canonicalExerciseID(exerciseID: lhs.id)
        let rhsKey = RecentExerciseTracker.canonicalExerciseID(exerciseID: rhs.id)
        let lhsPriority = priorityByCanonicalID[lhsKey]
        let rhsPriority = priorityByCanonicalID[rhsKey]

        switch (lhsPriority, rhsPriority) {
        case let (.some(l), .some(r)):
            if l != r { return l < r }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

/// Resolves weight/reps defaults from latest set or exercise defaults.
func resolvedDefaults(for exercise: WatchExerciseInfo) -> (weight: Double?, reps: Int) {
    let latest = RecentExerciseTracker.latestSet(exerciseID: exercise.id)
    let reps = latest?.reps ?? exercise.defaultReps ?? 10
    let weight = latest?.weight ?? exercise.defaultWeightKg
    return (weight: weight, reps: reps)
}

/// Creates a single-exercise template snapshot for navigation.
func snapshotFromExercise(_ exercise: WatchExerciseInfo) -> WorkoutSessionTemplate {
    let defaults = resolvedDefaults(for: exercise)
    let entry = TemplateEntry(
        exerciseDefinitionID: exercise.id,
        exerciseName: exercise.name,
        defaultSets: exercise.defaultSets,
        defaultReps: defaults.reps,
        defaultWeightKg: defaults.weight,
        equipment: exercise.equipment
    )
    return WorkoutSessionTemplate(
        name: exercise.name,
        entries: [entry]
    )
}

/// Lightweight view snapshot used to render routine cards from either SwiftData or WatchConnectivity.
struct WatchRoutineTemplateSnapshot: Sendable {
    let id: UUID
    let name: String
    let entries: [TemplateEntry]
    let updatedAt: Date
}

/// Merges local (CloudKit-backed) templates with WatchConnectivity templates.
/// Local templates take precedence when IDs overlap.
func mergedRoutineTemplates(
    local: [WorkoutTemplate],
    synced: [WatchWorkoutTemplateInfo]
) -> [WatchRoutineTemplateSnapshot] {
    var templatesByID: [UUID: WatchRoutineTemplateSnapshot] = [:]

    for template in synced {
        templatesByID[template.id] = WatchRoutineTemplateSnapshot(
            id: template.id,
            name: template.name,
            entries: template.entries,
            updatedAt: template.updatedAt
        )
    }

    for template in local {
        templatesByID[template.id] = WatchRoutineTemplateSnapshot(
            id: template.id,
            name: template.name,
            entries: template.exerciseEntries,
            updatedAt: template.updatedAt
        )
    }

    return templatesByID.values.sorted { lhs, rhs in
        lhs.updatedAt > rhs.updatedAt
    }
}

// MARK: - Quick Start Search/Filter Helpers

enum WatchExerciseCategory: CaseIterable, Sendable {
    case strength
    case bodyweight
    case cardio
    case hiit
    case flexibility
    case other

    static var ordered: [WatchExerciseCategory] {
        [.strength, .bodyweight, .cardio, .hiit, .flexibility, .other]
    }

    init(inputTypeRaw: String) {
        switch inputTypeRaw {
        case "setsRepsWeight", "weight_reps":
            self = .strength
        case "setsReps", "bodyweight_reps":
            self = .bodyweight
        case "durationDistance", "duration":
            self = .cardio
        case "roundsBased":
            self = .hiit
        case "durationIntensity":
            self = .flexibility
        default:
            self = .other
        }
    }

    var displayName: String {
        switch self {
        case .strength: return String(localized: "Strength")
        case .bodyweight: return String(localized: "Bodyweight")
        case .cardio: return String(localized: "Cardio")
        case .hiit: return String(localized: "HIIT")
        case .flexibility: return String(localized: "Flexibility")
        case .other: return String(localized: "Other")
        }
    }
}

func groupedWatchExercisesByCategory(
    _ exercises: [WatchExerciseInfo]
) -> [(category: WatchExerciseCategory, exercises: [WatchExerciseInfo])] {
    let grouped = Dictionary(grouping: exercises) { WatchExerciseCategory(inputTypeRaw: $0.inputType) }
    return WatchExerciseCategory.ordered.compactMap { category in
        guard let items = grouped[category], !items.isEmpty else { return nil }
        return (category: category, exercises: items)
    }
}

func filterWatchExercises(
    exercises: [WatchExerciseInfo],
    query: String,
    category: WatchExerciseCategory?
) -> [WatchExerciseInfo] {
    let normalizedQuery = normalizedSearchToken(query)
    let queryTerms = normalizedQuery.split(separator: " ").map(String.init)

    return exercises.filter { exercise in
        if let category, WatchExerciseCategory(inputTypeRaw: exercise.inputType) != category {
            return false
        }
        guard !queryTerms.isEmpty else { return true }
        let tokens = searchTokens(for: exercise)
        return queryTerms.allSatisfy { term in
            tokens.contains(where: { $0.contains(term) })
        }
    }
}

private func searchTokens(for exercise: WatchExerciseInfo) -> Set<String> {
    var tokens: Set<String> = []
    let category = WatchExerciseCategory(inputTypeRaw: exercise.inputType)

    let baseCandidates = [exercise.name, exercise.id] + (exercise.aliases ?? [])
    for candidate in baseCandidates {
        let token = normalizedSearchToken(candidate)
        if !token.isEmpty {
            tokens.insert(token)
        }
    }

    tokens.formUnion(categorySearchKeywords(for: category))

    if let equipment = exercise.equipment {
        tokens.formUnion(equipmentSearchKeywords(for: equipment))
    }

    return tokens
}

private func normalizedSearchToken(_ raw: String) -> String {
    let camelSeparated = raw.replacingOccurrences(
        of: "([a-z0-9])([A-Z])",
        with: "$1 $2",
        options: .regularExpression
    )
    let punctSeparated = camelSeparated.replacingOccurrences(
        of: "[-_./]",
        with: " ",
        options: .regularExpression
    )
    let folded = punctSeparated.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    return folded
        .lowercased()
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func categorySearchKeywords(for category: WatchExerciseCategory) -> Set<String> {
    switch category {
    case .strength:
        return normalizedKeywordSet(["strength", "weights", "근력", "웨이트"])
    case .bodyweight:
        return normalizedKeywordSet(["bodyweight", "맨몸", "체중", "calisthenics"])
    case .cardio:
        return normalizedKeywordSet(["cardio", "유산소", "러닝", "런닝", "endurance"])
    case .hiit:
        return normalizedKeywordSet(["hiit", "interval", "인터벌"])
    case .flexibility:
        return normalizedKeywordSet(["flexibility", "stretch", "스트레칭", "유연성"])
    case .other:
        return normalizedKeywordSet(["other", "기타"])
    }
}

private func equipmentSearchKeywords(for equipmentRaw: String) -> Set<String> {
    let base = normalizedKeywordSet([equipmentRaw])

    let knownKeywords: [String: [String]] = [
        "barbell": ["barbell", "바벨"],
        "dumbbell": ["dumbbell", "덤벨"],
        "kettlebell": ["kettlebell", "케틀벨"],
        "ezBar": ["ez bar", "이지바"],
        "trapBar": ["trap bar", "트랩바"],
        "smithMachine": ["smith machine", "스미스", "스미스 머신"],
        "legPressMachine": ["leg press", "레그프레스", "레그 프레스"],
        "hackSquatMachine": ["hack squat", "핵스쿼트", "핵 스쿼트"],
        "chestPressMachine": ["chest press", "체스트프레스", "체스트 프레스"],
        "shoulderPressMachine": ["shoulder press", "숄더프레스", "숄더 프레스"],
        "latPulldownMachine": ["lat pulldown", "랫풀다운", "랫 풀다운"],
        "legExtensionMachine": ["leg extension", "레그익스텐션", "레그 익스텐션"],
        "legCurlMachine": ["leg curl", "레그컬", "레그 컬"],
        "pecDeckMachine": ["pec deck", "펙덱", "펙 덱", "팩덱"],
        "cableMachine": ["cable", "케이블", "cable machine"],
        "machine": ["machine", "머신"],
        "cable": ["cable", "케이블"],
        "bodyweight": ["bodyweight", "맨몸", "체중"],
        "pullUpBar": ["pull up bar", "풀업바", "철봉", "턱걸이 바"],
        "dipStation": ["dip station", "딥스", "딥 스테이션"],
        "band": ["band", "밴드", "저항 밴드"],
        "trx": ["trx"],
        "medicineBall": ["medicine ball", "메디신볼", "메디신 볼"],
        "stabilityBall": ["stability ball", "짐볼"],
        "other": ["other", "기타"]
    ]

    guard let keywords = knownKeywords[equipmentRaw] else {
        return base
    }

    return base.union(normalizedKeywordSet(keywords))
}

private func normalizedKeywordSet(_ rawKeywords: [String]) -> Set<String> {
    Set(rawKeywords.map(normalizedSearchToken).filter { !$0.isEmpty })
}
