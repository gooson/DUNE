import Foundation

/// Persists dismissed insight card IDs per day.
/// Entries older than 3 days are automatically cleaned up on read.
final class InsightCardDismissStore: @unchecked Sendable {
    static let shared = InsightCardDismissStore()

    private let defaults: UserDefaults
    private let keyPrefix: String
    private static let cleanupThresholdDays = 3

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let bundleID = Bundle.main.bundleIdentifier ?? "com.dailve"
        self.keyPrefix = "\(bundleID).insightDismiss"
    }

    /// Check if a card was dismissed for the given date.
    func isDismissed(cardID: String, on date: Date = Date()) -> Bool {
        let key = storageKey(for: date)
        let dismissed = defaults.stringArray(forKey: key) ?? []
        return dismissed.contains(cardID)
    }

    /// Dismiss a card for the given date.
    func dismiss(cardID: String, on date: Date = Date()) {
        let key = storageKey(for: date)
        var dismissed = defaults.stringArray(forKey: key) ?? []
        guard !dismissed.contains(cardID) else { return }
        dismissed.append(cardID)
        defaults.set(dismissed, forKey: key)
        cleanupStaleEntries()
    }

    // MARK: - Private

    private func storageKey(for date: Date) -> String {
        let dateString = Self.dateFormatter.string(from: date)
        return "\(keyPrefix).\(dateString)"
    }

    private func cleanupStaleEntries() {
        let calendar = Calendar.current
        let threshold = calendar.date(
            byAdding: .day,
            value: -Self.cleanupThresholdDays,
            to: Date()
        ) ?? Date()

        // Scan for keys matching our prefix and remove old ones
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(keyPrefix) {
            // Extract date part: keyPrefix.YYYY-MM-dd
            let datePart = key.dropFirst(keyPrefix.count + 1) // +1 for the dot
            if let entryDate = Self.dateFormatter.date(from: String(datePart)),
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
