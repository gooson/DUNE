import Foundation

/// Tracks recently used exercises in UserDefaults for Quick Start sorting.
/// Stores a dictionary of [exerciseID: lastUsedTimestamp].
/// History is capped at `maxEntries` most recent; older entries are silently trimmed.
enum RecentExerciseTracker {
    private static let key = "\(Bundle.main.bundleIdentifier ?? "com.dailve").recentExercises"
    private static let maxEntries = 50

    /// Record that an exercise was just used.
    static func recordUsage(exerciseID: String) {
        guard !exerciseID.isEmpty else { return }
        var history = loadHistory()
        history[exerciseID] = Date().timeIntervalSince1970
        // Trim old entries if exceeding max
        if history.count > maxEntries {
            let sorted = history.sorted { $0.value > $1.value }
            history = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(maxEntries)))
        }
        UserDefaults.standard.set(history, forKey: key)
    }

    /// Returns the last-used timestamp for a given exercise, or nil if never used.
    static func lastUsed(exerciseID: String) -> Date? {
        let history = loadHistory()
        guard let timestamp = history[exerciseID] else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Sort exercises: recently used first (by recency), then unused alphabetically.
    /// Also cleans up stale IDs not present in the current library.
    static func sorted(_ exercises: [WatchExerciseInfo]) -> [WatchExerciseInfo] {
        var history = loadHistory()
        let validIDs = Set(exercises.map(\.id))

        // Purge stale exercise IDs no longer in the library
        let staleKeys = history.keys.filter { !validIDs.contains($0) }
        if !staleKeys.isEmpty {
            for key in staleKeys { history.removeValue(forKey: key) }
            UserDefaults.standard.set(history, forKey: key)
        }

        return exercises.sorted { a, b in
            let aTime = history[a.id]
            let bTime = history[b.id]
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

    private static func loadHistory() -> [String: Double] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
    }
}
