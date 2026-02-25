import Foundation

/// Persists personal records per activity type in UserDefaults.
/// Key prefix uses bundle identifier for test/production isolation (correction #76).
final class PersonalRecordStore: @unchecked Sendable {
    static let shared = PersonalRecordStore()

    private let defaults: UserDefaults
    private let keyPrefix: String

    private static let maxEntriesPerType = 5

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.keyPrefix = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".personalRecords."
    }

    /// Returns current records for the given activity type.
    func records(for activityType: WorkoutActivityType) -> [PersonalRecordType: PersonalRecord] {
        let key = keyPrefix + activityType.rawValue
        guard let data = defaults.data(forKey: key) else { return [:] }
        do {
            return try JSONDecoder().decode([PersonalRecordType: PersonalRecord].self, from: data)
        } catch {
            // Corrupted data — reset
            defaults.removeObject(forKey: key)
            return [:]
        }
    }

    /// Checks a workout against existing records and updates if any new PRs.
    /// Returns the list of newly achieved PR types.
    @discardableResult
    func updateIfNewRecords(_ workout: WorkoutSummary) -> [PersonalRecordType] {
        let existing = records(for: workout.activityType)
        let newTypes = PersonalRecordService.detectNewRecords(
            workout: workout,
            existingRecords: existing
        )
        guard !newTypes.isEmpty else { return [] }

        let newRecords = PersonalRecordService.buildRecords(from: workout, types: newTypes)
        var updated = existing
        for (type, record) in newRecords {
            updated[type] = record
        }

        save(updated, for: workout.activityType)
        return newTypes
    }

    /// Returns all records across all activity types (for Training Load / summary views).
    func allRecords() -> [WorkoutActivityType: [PersonalRecordType: PersonalRecord]] {
        var result: [WorkoutActivityType: [PersonalRecordType: PersonalRecord]] = [:]
        for activityType in WorkoutActivityType.allCases {
            let records = records(for: activityType)
            if !records.isEmpty {
                result[activityType] = records
            }
        }
        return result
    }

    // MARK: - Private

    private func save(_ records: [PersonalRecordType: PersonalRecord], for activityType: WorkoutActivityType) {
        let key = keyPrefix + activityType.rawValue
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }
}
