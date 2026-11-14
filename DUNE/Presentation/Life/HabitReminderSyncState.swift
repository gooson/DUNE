import Foundation

/// Tracks the persisted inputs that can change a habit reminder.
struct HabitReminderSyncState {
    struct Log: Equatable {
        let habitID: UUID?
        let signature: Int
    }

    struct Snapshot: Equatable {
        let habits: [UUID: Int]
        let logs: [UUID: Log]
        let autoLinkedHabitIDs: Set<UUID>
        let todayExerciseExists: Bool
        let generation: Int
    }

    struct Plan: Equatable {
        let habitIDs: Set<UUID>
        let cleanUpOrphans: Bool
    }

    private var previous: Snapshot?

    mutating func plan(for current: Snapshot) -> Plan {
        let previousSnapshot = previous
        previous = current
        guard let previous = previousSnapshot else {
            return Plan(habitIDs: Set(current.habits.keys), cleanUpOrphans: true)
        }

        let previousIDs = Set(previous.habits.keys)
        let currentIDs = Set(current.habits.keys)
        if previous.generation != current.generation {
            return Plan(habitIDs: currentIDs, cleanUpOrphans: true)
        }

        var changed = Set(current.habits.compactMap { id, signature in
            previous.habits[id] == signature ? nil : id
        })
        for (id, log) in current.logs where previous.logs[id] != log {
            if let habitID = log.habitID { changed.insert(habitID) }
            if let oldHabitID = previous.logs[id]?.habitID { changed.insert(oldHabitID) }
        }
        for (id, log) in previous.logs where current.logs[id] == nil {
            if let habitID = log.habitID { changed.insert(habitID) }
        }
        if previous.todayExerciseExists != current.todayExerciseExists {
            changed.formUnion(current.autoLinkedHabitIDs)
        }
        return Plan(habitIDs: changed.intersection(currentIDs),
                    cleanUpOrphans: previousIDs != currentIDs)
    }

    static func exerciseExists(
        on dates: [Date],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        dates.contains { calendar.isDate($0, inSameDayAs: referenceDate) }
    }
}
