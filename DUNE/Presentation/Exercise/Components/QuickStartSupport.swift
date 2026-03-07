import Foundation

enum QuickStartSupport {
    static func resolveExerciseDefinition(
        by id: String,
        library: ExerciseLibraryQuerying,
        customDefinitions: [ExerciseDefinition]
    ) -> ExerciseDefinition? {
        library.representativeExercise(byID: id)
            ?? customDefinitions.first { $0.id == id }
    }

    static func uniqueByID(_ exercises: [ExerciseDefinition]) -> [ExerciseDefinition] {
        var seen = Set<String>()
        return exercises.filter { seen.insert($0.id).inserted }
    }

    static func uniqueByCanonical(_ exercises: [ExerciseDefinition]) -> [ExerciseDefinition] {
        var seen = Set<String>()
        return exercises.filter { exercise in
            let key = canonicalKey(for: exercise)
            return seen.insert(key).inserted
        }
    }

    static func canonicalKey(for exercise: ExerciseDefinition) -> String {
        QuickStartCanonicalService.canonicalKey(
            exerciseID: exercise.id,
            exerciseName: exercise.localizedName
        ) ?? exercise.id
    }

    static func sortQuickStartExercises(
        _ exercises: [ExerciseDefinition],
        priorityIDs: [String]
    ) -> [ExerciseDefinition] {
        let priority = Dictionary(
            uniqueKeysWithValues: dedupedIDs(priorityIDs).enumerated().map { ($1, $0) }
        )

        return exercises.sorted { lhs, rhs in
            let lhsPriority = priority[lhs.id]
            let rhsPriority = priority[rhs.id]

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

            return lhs.localizedName.localizedCaseInsensitiveCompare(rhs.localizedName) == .orderedAscending
        }
    }

    static func mergedSearchResults(
        for query: String,
        library: ExerciseLibraryQuerying
    ) -> [ExerciseDefinition] {
        let baseResults = library.search(query: query)
        let initialConsonantResults = library.allExercises().filter {
            matchesInitialConsonantQuery(query, in: $0)
        }
        return uniqueByID(baseResults + initialConsonantResults)
    }

    static func matchesSearchQuery(_ query: String, in exercise: ExerciseDefinition) -> Bool {
        exercise.localizedName.localizedCaseInsensitiveContains(query)
            || exercise.name.localizedCaseInsensitiveContains(query)
            || matchesInitialConsonantQuery(query, in: exercise)
    }

    private static func dedupedIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    private static func matchesInitialConsonantQuery(
        _ query: String,
        in exercise: ExerciseDefinition
    ) -> Bool {
        let normalizedQuery = query.replacingOccurrences(of: " ", with: "")
        guard !normalizedQuery.isEmpty, normalizedQuery.allSatisfy(\.isHangulInitialConsonant) else {
            return false
        }

        let localizedInitials = exercise.localizedName.hangulInitialConsonants
        let englishInitials = exercise.name.hangulInitialConsonants
        return localizedInitials.contains(normalizedQuery) || englishInitials.contains(normalizedQuery)
    }
}

private extension Character {
    var isHangulInitialConsonant: Bool {
        guard let scalar = unicodeScalars.first, unicodeScalars.count == 1 else { return false }
        return HangulInitialConsonantMatcher.initialConsonants.contains(scalar)
    }
}

private enum HangulInitialConsonantMatcher {
    static let initialConsonants = Set("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ".unicodeScalars)
    static let table: [Character] = ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
    static let hangulSyllableStart: UInt32 = 0xAC00
    static let hangulSyllableEnd: UInt32 = 0xD7A3
    static let choseongCycle: UInt32 = 588
}

private extension String {
    var hangulInitialConsonants: String {
        var result = String()

        for scalar in unicodeScalars {
            let value = scalar.value
            if HangulInitialConsonantMatcher.initialConsonants.contains(scalar) {
                result.append(Character(scalar))
                continue
            }

            guard value >= HangulInitialConsonantMatcher.hangulSyllableStart,
                  value <= HangulInitialConsonantMatcher.hangulSyllableEnd else {
                continue
            }

            let offset = value - HangulInitialConsonantMatcher.hangulSyllableStart
            let initialIndex = Int(offset / HangulInitialConsonantMatcher.choseongCycle)
            guard HangulInitialConsonantMatcher.table.indices.contains(initialIndex) else { continue }
            result.append(HangulInitialConsonantMatcher.table[initialIndex])
        }

        return result
    }
}
