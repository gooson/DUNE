import Foundation

/// Tracks recently used exercises in UserDefaults for Quick Start sorting.
/// Stores dictionaries for:
/// - last used timestamp: [exerciseID: timestamp]
/// - usage count: [exerciseID: count]
/// History is capped at `maxEntries` most recent; older entries are silently trimmed.
enum RecentExerciseTracker {
    private static let baseKey = "\(Bundle.main.bundleIdentifier ?? "com.dailve").recentExercises"
    private static let lastUsedKey = "\(baseKey).lastUsed"
    private static let usageCountKey = "\(baseKey).usageCount"
    private static let maxEntries = 50

    /// Record that an exercise was just used.
    static func recordUsage(exerciseID: String) {
        guard !exerciseID.isEmpty else { return }
        var lastUsed = loadLastUsedHistory()
        var usageCounts = loadUsageCounts()

        lastUsed[exerciseID] = Date().timeIntervalSince1970
        usageCounts[exerciseID, default: 0] += 1

        // Trim old entries if exceeding max
        if lastUsed.count > maxEntries {
            let keepIDs = Set(lastUsed
                .sorted { $0.value > $1.value }
                .prefix(maxEntries)
                .map(\.key)
            )
            lastUsed = lastUsed.filter { keepIDs.contains($0.key) }
            usageCounts = usageCounts.filter { keepIDs.contains($0.key) }
        }

        persistLastUsedHistory(lastUsed)
        persistUsageCounts(usageCounts)
    }

    /// Returns the last-used timestamp for a given exercise, or nil if never used.
    static func lastUsed(exerciseID: String) -> Date? {
        let history = loadLastUsedHistory()
        guard let timestamp = history[exerciseID] else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Returns the usage count for a given exercise, or 0 if never used.
    static func usageCount(exerciseID: String) -> Int {
        loadUsageCounts()[exerciseID] ?? 0
    }

    /// Sort exercises: recently used first (by recency), then unused alphabetically.
    /// Also cleans up stale IDs not present in the current library.
    static func sorted(_ exercises: [WatchExerciseInfo]) -> [WatchExerciseInfo] {
        var lastUsed = loadLastUsedHistory()
        var usageCounts = loadUsageCounts()
        let validIDs = Set(exercises.map(\.id))

        // Purge stale exercise IDs no longer in the library
        let didPurge = purgeInvalid(
            validIDs: validIDs,
            lastUsed: &lastUsed,
            usageCounts: &usageCounts
        )
        if didPurge {
            persistLastUsedHistory(lastUsed)
            persistUsageCounts(usageCounts)
        }

        return exercises.sorted { a, b in
            let aTime = lastUsed[a.id]
            let bTime = lastUsed[b.id]
            switch (aTime, bTime) {
            case let (.some(at), .some(bt)):
                return at > bt // Both used: more recent first
            case (.some, .none):
                return true // Used before unused
            case (.none, .some):
                return false
            case (.none, .none):
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
    }

    /// Personalized ranking: usage count first, recency second.
    /// If history is insufficient, fills remaining slots from alphabetical list.
    static func personalizedPopular(
        from exercises: [WatchExerciseInfo],
        limit: Int = 10
    ) -> [WatchExerciseInfo] {
        guard limit > 0, !exercises.isEmpty else { return [] }

        var lastUsed = loadLastUsedHistory()
        var usageCounts = loadUsageCounts()
        let validIDs = Set(exercises.map(\.id))

        let didPurge = purgeInvalid(
            validIDs: validIDs,
            lastUsed: &lastUsed,
            usageCounts: &usageCounts
        )
        if didPurge {
            persistLastUsedHistory(lastUsed)
            persistUsageCounts(usageCounts)
        }

        let ranked = exercises.sorted { a, b in
            let aCount = usageCounts[a.id] ?? 0
            let bCount = usageCounts[b.id] ?? 0
            if aCount != bCount { return aCount > bCount }

            let aTime = lastUsed[a.id] ?? Date.distantPast.timeIntervalSince1970
            let bTime = lastUsed[b.id] ?? Date.distantPast.timeIntervalSince1970
            if aTime != bTime { return aTime > bTime }

            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        let personalized = ranked.filter {
            (usageCounts[$0.id] ?? 0) > 0 || lastUsed[$0.id] != nil
        }

        var results = Array(personalized.prefix(limit))
        if results.count < limit {
            let existingIDs = Set(results.map { $0.id })
            let fallback = sorted(exercises).filter { !existingIDs.contains($0.id) }
            results.append(contentsOf: fallback.prefix(limit - results.count))
        }
        return results
    }

    @discardableResult
    private static func purgeInvalid(
        validIDs: Set<String>,
        lastUsed: inout [String: Double],
        usageCounts: inout [String: Int]
    ) -> Bool {
        let staleLastUsed = Set(lastUsed.keys.filter { !validIDs.contains($0) })
        let staleUsage = Set(usageCounts.keys.filter { !validIDs.contains($0) })
        let staleIDs = staleLastUsed.union(staleUsage)
        guard !staleIDs.isEmpty else { return false }

        for id in staleIDs {
            lastUsed.removeValue(forKey: id)
            usageCounts.removeValue(forKey: id)
        }
        return true
    }

    private static func loadLastUsedHistory() -> [String: Double] {
        if let value = UserDefaults.standard.dictionary(forKey: lastUsedKey) as? [String: Double] {
            return value
        }
        // Backward compatibility: old versions stored lastUsed in baseKey.
        return UserDefaults.standard.dictionary(forKey: baseKey) as? [String: Double] ?? [:]
    }

    private static func loadUsageCounts() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: usageCountKey) as? [String: Int] ?? [:]
    }

    private static func persistLastUsedHistory(_ history: [String: Double]) {
        // Keep writing legacy key for compatibility with old app versions.
        UserDefaults.standard.set(history, forKey: baseKey)
        UserDefaults.standard.set(history, forKey: lastUsedKey)
    }

    private static func persistUsageCounts(_ usageCounts: [String: Int]) {
        UserDefaults.standard.set(usageCounts, forKey: usageCountKey)
    }
}
