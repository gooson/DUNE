import Foundation

/// Persists dismissed insight card IDs per day.
/// Entries older than 3 days are automatically cleaned up (throttled to once per day).
@MainActor
final class InsightCardDismissStore {
    static let shared = InsightCardDismissStore()

    private let defaults: UserDefaults
    private let keyPrefix: String
    private static let cleanupThresholdDays = 3

    /// Cached dismissed IDs for the current date to avoid repeated UserDefaults reads.
    private var cachedDismissedIDs: Set<String> = []
    private var cachedDate: String = ""

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let bundleID = Bundle.main.bundleIdentifier ?? "com.dailve"
        self.keyPrefix = "\(bundleID).insightDismiss"
    }

    /// Check if a card was dismissed for the given date.
    func isDismissed(cardID: String, on date: Date = Date()) -> Bool {
        ensureCache(for: date)
        return cachedDismissedIDs.contains(cardID)
    }

    /// Return all dismissed card IDs for the given date (batch access).
    func dismissedIDs(on date: Date = Date()) -> Set<String> {
        ensureCache(for: date)
        return cachedDismissedIDs
    }

    /// Dismiss a card for the given date.
    func dismiss(cardID: String, on date: Date = Date()) {
        ensureCache(for: date)
        guard !cachedDismissedIDs.contains(cardID) else { return }
        cachedDismissedIDs.insert(cardID)

        let key = storageKey(for: date)
        defaults.set(Array(cachedDismissedIDs), forKey: key)
        cleanupStaleEntriesIfNeeded()
    }

    // MARK: - Private

    private func ensureCache(for date: Date) {
        let dateString = Self.dateFormatter.string(from: date)
        guard dateString != cachedDate else { return }
        cachedDate = dateString
        let key = "\(keyPrefix).\(dateString)"
        let stored = defaults.stringArray(forKey: key) ?? []
        cachedDismissedIDs = Set(stored)
    }

    private func storageKey(for date: Date) -> String {
        let dateString = Self.dateFormatter.string(from: date)
        return "\(keyPrefix).\(dateString)"
    }

    /// Throttled cleanup: only run once per day.
    private func cleanupStaleEntriesIfNeeded() {
        let todayString = Self.dateFormatter.string(from: Date())
        let lastCleanupKey = "\(keyPrefix).lastCleanup"
        let lastCleanup = defaults.string(forKey: lastCleanupKey) ?? ""
        guard lastCleanup != todayString else { return }

        defaults.set(todayString, forKey: lastCleanupKey)

        let calendar = Calendar.current
        let threshold = calendar.date(
            byAdding: .day,
            value: -Self.cleanupThresholdDays,
            to: Date()
        ) ?? Date()

        // Only scan keys matching our prefix
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(keyPrefix) {
            // Skip non-date keys (e.g. lastCleanup)
            let suffix = key.dropFirst(keyPrefix.count + 1) // +1 for the dot
            guard suffix.count == 10 else { continue } // YYYY-MM-dd format
            if let entryDate = Self.dateFormatter.date(from: String(suffix)),
               entryDate < threshold {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
