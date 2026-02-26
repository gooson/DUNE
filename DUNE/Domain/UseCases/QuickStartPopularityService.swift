import Foundation

enum QuickStartPopularityService {
    struct Usage: Sendable {
        let exerciseDefinitionID: String
        let date: Date
    }

    /// Returns exercise IDs ordered by popularity.
    /// Priority: higher usage count -> more recent last usage -> stable ID sort.
    static func popularExerciseIDs(
        from usages: [Usage],
        limit: Int = 10,
        canonicalize: ((String) -> String)? = nil
    ) -> [String] {
        guard limit > 0 else { return [] }

        struct GroupStats {
            var count: Int
            var lastDate: Date
            var representativeID: String
            var representativeDate: Date
        }

        var stats: [String: GroupStats] = [:]
        for usage in usages where !usage.exerciseDefinitionID.isEmpty {
            let groupKey = canonicalize?(usage.exerciseDefinitionID) ?? usage.exerciseDefinitionID
            var entry = stats[groupKey] ?? GroupStats(
                count: 0,
                lastDate: .distantPast,
                representativeID: usage.exerciseDefinitionID,
                representativeDate: .distantPast
            )
            entry.count += 1
            if usage.date > entry.lastDate {
                entry.lastDate = usage.date
            }
            if usage.date > entry.representativeDate
                || (usage.date == entry.representativeDate
                    && usage.exerciseDefinitionID < entry.representativeID)
            {
                entry.representativeID = usage.exerciseDefinitionID
                entry.representativeDate = usage.date
            }
            stats[groupKey] = entry
        }

        return stats
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count {
                    return lhs.value.count > rhs.value.count
                }
                if lhs.value.lastDate != rhs.value.lastDate {
                    return lhs.value.lastDate > rhs.value.lastDate
                }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map(\.value.representativeID)
    }
}

enum QuickStartCanonicalService {
    private static let leadingPrefixes = [
        "tempo-",
        "paused-",
        "pause-",
        "endurance-",
        "isometric-",
    ]

    private static let trailingSuffixes = [
        "-tempo",
        "-paused",
        "-pause",
        "-endurance-sets",
        "-endurance",
        "-isometric-hold",
        "-isometric",
        "-hold",
    ]

    private static let nameSuffixes = [
        " tempo",
        " paused",
        " pause",
        " endurance sets",
        " endurance",
        " isometric hold",
        " isometric",
        " hold",
        " 템포",
        " 일시정지",
        " 지구력 세트",
        " 지구력",
        " 아이소메트릭 홀드",
        " 아이소메트릭",
        " 홀드",
    ]

    static func canonicalExerciseID(for exerciseID: String) -> String {
        var normalized = exerciseID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return normalized }

        for prefix in leadingPrefixes where normalized.hasPrefix(prefix) {
            normalized.removeFirst(prefix.count)
            break
        }

        var changed = true
        while changed {
            changed = false
            for suffix in trailingSuffixes where normalized.hasSuffix(suffix) {
                normalized.removeLast(suffix.count)
                changed = true
                break
            }
        }

        return normalized.trimmingCharacters(in: CharacterSet(charactersIn: "- "))
    }

    static func canonicalExerciseName(for exerciseName: String) -> String {
        var normalized = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return normalized }

        var changed = true
        while changed {
            changed = false
            for suffix in nameSuffixes where normalized.hasSuffix(suffix) {
                normalized.removeLast(suffix.count)
                normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
                changed = true
                break
            }
        }

        return normalized
    }

    static func canonicalKey(exerciseID: String?, exerciseName: String? = nil) -> String? {
        if let exerciseID, !exerciseID.isEmpty {
            let key = canonicalExerciseID(for: exerciseID)
            return key.isEmpty ? nil : key
        }
        if let exerciseName, !exerciseName.isEmpty {
            let key = canonicalExerciseName(for: exerciseName)
            return key.isEmpty ? nil : key
        }
        return nil
    }
}
