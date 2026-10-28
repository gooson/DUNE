import Foundation

/// Resolves manual daily totals after independent CloudKit writes converge.
@MainActor
enum HabitLogResolution {
    static let dailyTotalMemo = "[dune-life-daily-total]"
    private static let skipMemo = "[dune-life-cycle-skip]"
    private static let snoozeMemo = "[dune-life-cycle-snooze]"

    private struct DayKey: Hashable {
        let habitID: UUID
        let day: Date
    }

    static func resolve(_ logs: [HabitLog], habitID: UUID? = nil) -> [HabitLog] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: logs) {
            DayKey(habitID: habitID ?? $0.habitDefinition?.id ?? $0.id, day: calendar.startOfDay(for: $0.date))
        }
        var retainedIDs = Set<UUID>()

        for dayLogs in groups.values {
            guard let winner = dayLogs.filter({ !$0.isAutoCompleted && $0.memo == dailyTotalMemo })
                .max(by: isEarlier) else {
                retainedIDs.formUnion(dayLogs.map(\.id))
                continue
            }

            retainedIDs.insert(winner.id)
            for log in dayLogs where log.isAutoCompleted {
                retainedIDs.insert(log.id)
            }
            // An explicit cycle action made after the total remains an event.
            for log in dayLogs where isCycleAction(log) && isEarlier(winner, log) {
                retainedIDs.insert(log.id)
            }
        }

        return logs.filter { retainedIDs.contains($0.id) }
    }

    static func isZeroTombstone(_ log: HabitLog) -> Bool {
        !log.isAutoCompleted && log.memo == dailyTotalMemo && log.value == 0
    }

    static func isEarlier(_ lhs: HabitLog, _ rhs: HabitLog) -> Bool {
        let leftTime = lhs.completedAt ?? .distantPast
        let rightTime = rhs.completedAt ?? .distantPast
        if leftTime != rightTime { return leftTime < rightTime }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func isCycleAction(_ log: HabitLog) -> Bool {
        !log.isAutoCompleted && (log.memo == skipMemo || log.memo == snoozeMemo)
    }
}
