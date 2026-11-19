import Foundation

/// Tracks the persisted inputs that can change a habit reminder.
struct HabitReminderSyncState {
    struct Log: Equatable {
        let habitID: UUID?
        let signature: Int
    }

    enum WorkoutSource: Equatable {
        case pending
        case resolved(Date?)
    }

    struct Snapshot: Equatable {
        let habits: [UUID: Int]
        let logs: [UUID: Log]
        let autoLinkedHabitIDs: Set<UUID>
        let workoutSource: WorkoutSource
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
            return Plan(habitIDs: eligibleIDs(Set(current.habits.keys), in: current), cleanUpOrphans: true)
        }

        let previousIDs = Set(previous.habits.keys)
        let currentIDs = Set(current.habits.keys)
        if previous.generation != current.generation {
            return Plan(habitIDs: eligibleIDs(currentIDs, in: current), cleanUpOrphans: true)
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
        if previous.workoutSource != current.workoutSource {
            changed.formUnion(current.autoLinkedHabitIDs)
        }
        return Plan(habitIDs: eligibleIDs(changed.intersection(currentIDs), in: current),
                    cleanUpOrphans: previousIDs != currentIDs)
    }

    private func eligibleIDs(_ habitIDs: Set<UUID>, in snapshot: Snapshot) -> Set<UUID> {
        guard snapshot.workoutSource == .pending else { return habitIDs }
        return habitIDs.subtracting(snapshot.autoLinkedHabitIDs)
    }
}
