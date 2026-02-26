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
        limit: Int = 10
    ) -> [String] {
        guard limit > 0 else { return [] }

        var stats: [String: (count: Int, lastDate: Date)] = [:]
        for usage in usages where !usage.exerciseDefinitionID.isEmpty {
            var entry = stats[usage.exerciseDefinitionID] ?? (count: 0, lastDate: .distantPast)
            entry.count += 1
            if usage.date > entry.lastDate {
                entry.lastDate = usage.date
            }
            stats[usage.exerciseDefinitionID] = entry
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
            .map(\.key)
    }
}
