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
    private static let latestSetByExerciseKey = "\(baseKey).latestSetByExercise"
    private static let latestSetByCanonicalKey = "\(baseKey).latestSetByCanonical"
    private static let maxEntries = 50

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

    struct LatestSetSnapshot: Codable, Sendable {
        let weight: Double?
        let reps: Int?
        let updatedAt: TimeInterval
    }

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

    /// Canonicalized exercise ID for integrating common variants.
    static func canonicalExerciseID(exerciseID: String) -> String {
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

    /// Record latest completed set metrics for Quick Start prefill.
    /// Lookup priority at read time: exact exercise ID -> canonical exercise ID.
    static func recordLatestSet(exerciseID: String, weight: Double?, reps: Int?) {
        guard !exerciseID.isEmpty else { return }

        let now = Date().timeIntervalSince1970
        let snapshot = LatestSetSnapshot(weight: weight, reps: reps, updatedAt: now)

        var byExercise = loadLatestSetByExercise()
        byExercise[exerciseID] = snapshot
        persistLatestSetByExercise(byExercise)

        let canonicalID = canonicalExerciseID(exerciseID: exerciseID)
        var byCanonical = loadLatestSetByCanonical()
        if let existing = byCanonical[canonicalID] {
            if snapshot.updatedAt >= existing.updatedAt {
                byCanonical[canonicalID] = snapshot
            }
        } else {
            byCanonical[canonicalID] = snapshot
        }
        persistLatestSetByCanonical(byCanonical)
    }

    /// Returns latest set snapshot for an exercise.
    /// Priority: exact ID first, then canonical ID fallback.
    static func latestSet(exerciseID: String) -> LatestSetSnapshot? {
        guard !exerciseID.isEmpty else { return nil }

        let byExercise = loadLatestSetByExercise()
        if let exact = byExercise[exerciseID] {
            return exact
        }

        let canonicalID = canonicalExerciseID(exerciseID: exerciseID)
        return loadLatestSetByCanonical()[canonicalID]
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

        struct CanonicalStats {
            var count: Int = 0
            var lastUsedAt: TimeInterval = Date.distantPast.timeIntervalSince1970
            var representative: WatchExerciseInfo?
            var representativeCount: Int = 0
            var representativeLastUsed: TimeInterval = Date.distantPast.timeIntervalSince1970
        }

        var grouped: [String: CanonicalStats] = [:]
        for exercise in exercises {
            let canonicalID = canonicalExerciseID(exerciseID: exercise.id)
            var stats = grouped[canonicalID] ?? CanonicalStats()

            let count = usageCounts[exercise.id] ?? 0
            let time = lastUsed[exercise.id] ?? Date.distantPast.timeIntervalSince1970
            stats.count += count
            stats.lastUsedAt = max(stats.lastUsedAt, time)

            let shouldReplaceRepresentative: Bool
            if stats.representative == nil {
                shouldReplaceRepresentative = true
            } else if count != stats.representativeCount {
                shouldReplaceRepresentative = count > stats.representativeCount
            } else if time != stats.representativeLastUsed {
                shouldReplaceRepresentative = time > stats.representativeLastUsed
            } else {
                shouldReplaceRepresentative =
                    exercise.name.localizedCaseInsensitiveCompare(
                        stats.representative?.name ?? exercise.name
                    ) == .orderedAscending
            }

            if shouldReplaceRepresentative {
                stats.representative = exercise
                stats.representativeCount = count
                stats.representativeLastUsed = time
            }

            grouped[canonicalID] = stats
        }

        let ranked = grouped.values
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                if lhs.lastUsedAt != rhs.lastUsedAt { return lhs.lastUsedAt > rhs.lastUsedAt }
                let lhsName = lhs.representative?.name ?? ""
                let rhsName = rhs.representative?.name ?? ""
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            }
            .compactMap(\.representative)
            .filter {
                (usageCounts[$0.id] ?? 0) > 0 || lastUsed[$0.id] != nil
            }

        var results = Array(ranked.prefix(limit))
        if results.count < limit {
            let existingCanonical = Set(results.map { canonicalExerciseID(exerciseID: $0.id) })
            let fallback = sorted(exercises).filter {
                !existingCanonical.contains(canonicalExerciseID(exerciseID: $0.id))
            }
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

    private static func loadLatestSetByExercise() -> [String: LatestSetSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: latestSetByExerciseKey),
              let decoded = try? JSONDecoder().decode([String: LatestSetSnapshot].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private static func loadLatestSetByCanonical() -> [String: LatestSetSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: latestSetByCanonicalKey),
              let decoded = try? JSONDecoder().decode([String: LatestSetSnapshot].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private static func persistLatestSetByExercise(_ snapshots: [String: LatestSetSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: latestSetByExerciseKey)
    }

    private static func persistLatestSetByCanonical(_ snapshots: [String: LatestSetSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: latestSetByCanonicalKey)
    }
}
