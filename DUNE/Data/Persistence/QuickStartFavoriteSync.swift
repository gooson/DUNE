import Foundation
import SwiftData

/// Each built-in exercise has one independent iCloud preference. No workout instance,
/// name, location, weight, repetitions, or last-used date is part of the wire format.
@MainActor
enum QuickStartFavoriteSync {
    private static let prefix = "dune.quickStart.favorite.v1."
    private static let pendingKey = "dune.quickStart.pendingFavorites.v1"

    static func isPreferenceKey(_ key: String) -> Bool {
        key.hasPrefix(prefix)
    }

    static func preferenceKey(for exerciseID: String) -> String? {
        guard ExerciseLibraryService.shared.exercise(byID: exerciseID)?.id == exerciseID else { return nil }
        return prefix + exerciseID
    }

    static func didEdit(_ preferred: Bool, exerciseID: String, in context: ModelContext) {
        guard let key = preferenceKey(for: exerciseID) else { return }
        do {
            try context.save()
        } catch {
            AppLogger.data.error("Could not save Quick Start preference: \(error, privacy: .private)")
            return
        }
        let defaults = UserDefaults.standard
        var pending = defaults.dictionary(forKey: pendingKey) as? [String: Bool] ?? [:]
        pending[key] = preferred
        defaults.set(pending, forKey: pendingKey)
        synchronize(in: context)
    }

    @discardableResult
    static func synchronize(in context: ModelContext) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: CloudSyncPreferenceStore.storageKey) else { return false }
        let cloud = NSUbiquitousKeyValueStore.default
        guard cloud.synchronize() else { return false }

        do {
            let records = try context.fetch(FetchDescriptor<ExerciseDefaultRecord>())
            var remote = cloud.dictionaryRepresentation
            let pending = defaults.dictionary(forKey: pendingKey) as? [String: Bool] ?? [:]
            for (key, preferred) in pending where isPreferenceKey(key) {
                let id = String(key.dropFirst(prefix.count))
                guard preferenceKey(for: id) == key else { continue }
                remote[key] = preferred
                cloud.set(preferred, forKey: key)
            }

            // Seed stars from pre-upgrade devices; an explicit remote unstar wins.
            for row in records where row.isPreferred {
                guard let key = preferenceKey(for: row.exerciseDefinitionID), remote[key] == nil else { continue }
                remote[key] = true
                cloud.set(true, forKey: key)
            }
            let changes = remote.compactMap { key, value -> (String, Bool)? in
                guard isPreferenceKey(key), let preferred = value as? Bool else { return nil }
                let id = String(key.dropFirst(prefix.count))
                guard preferenceKey(for: id) == key else { return nil }
                return (id, preferred)
            }
            let didChange = apply(changes, to: records, in: context)
            if didChange {
                try context.save()
                WatchSessionManager.shared.syncExerciseLibraryDefaultsToWatch(using: context)
            }
            guard cloud.synchronize() else { return false }
            defaults.removeObject(forKey: pendingKey)
            return true
        } catch {
            AppLogger.data.error("Could not restore Quick Start favorites: \(error, privacy: .private)")
            return false
        }
    }

    static func apply(
        _ preferences: [(String, Bool)],
        to records: [ExerciseDefaultRecord],
        in context: ModelContext
    ) -> Bool {
        let byID = Dictionary(grouping: records, by: \.exerciseDefinitionID)
        var changed = false
        for (id, preferred) in preferences {
            if let existing = byID[id] {
                for record in existing where record.isPreferred != preferred {
                    record.isPreferred = preferred
                    changed = true
                }
            } else if preferred {
                // A restored star is not evidence that the person did this exercise today.
                context.insert(ExerciseDefaultRecord(exerciseDefinitionID: id, isPreferred: true, lastUsedDate: .distantPast))
                changed = true
            }
        }
        return changed
    }
}
