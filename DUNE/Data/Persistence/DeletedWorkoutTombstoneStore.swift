import Foundation

/// Tracks deleted workout healthKitWorkoutIDs to prevent re-creation via bulk sync or backfill.
/// Entries older than 90 days are automatically cleaned up.
@MainActor
final class DeletedWorkoutTombstoneStore {
    static let shared = DeletedWorkoutTombstoneStore()

    private let defaults: UserDefaults
    private let storageKey: String
    private static let maxAgeDays = 90

    /// Cached set for fast lookup without repeated UserDefaults reads.
    private var cache: [String: Date] = [:]
    private var isCacheLoaded = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let bundleID = Bundle.main.bundleIdentifier ?? "com.dailve"
        self.storageKey = "\(bundleID).deletedWorkoutTombstones"
    }

    /// Record a deleted workout's healthKitWorkoutID.
    func recordDeletion(healthKitWorkoutID: String) {
        ensureCache()
        cache[healthKitWorkoutID] = Date()
        persist()
    }

    /// Check if a healthKitWorkoutID was previously deleted.
    func isDeleted(healthKitWorkoutID: String) -> Bool {
        ensureCache()
        return cache[healthKitWorkoutID] != nil
    }

    /// All currently tombstoned HealthKit workout IDs (for batch filtering).
    var tombstonedIDs: Set<String> {
        ensureCache()
        return Set(cache.keys)
    }

    // MARK: - Private

    private func ensureCache() {
        guard !isCacheLoaded else { return }
        isCacheLoaded = true

        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return
        }
        cache = decoded
        cleanup()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func cleanup() {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -Self.maxAgeDays,
            to: Date()
        ) ?? Date()
        let before = cache.count
        cache = cache.filter { $0.value >= cutoff }
        if cache.count < before {
            persist()
        }
    }
}
