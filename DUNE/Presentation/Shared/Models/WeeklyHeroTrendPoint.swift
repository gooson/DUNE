import Foundation

/// A recorded daily value. Nil is a missing observation, never a zero score.
struct WeeklyHeroTrendPoint: Identifiable, Sendable, Equatable {
    let date: Date
    let value: Int?

    var id: Date { date }

    static func readinessHistory(
        samples: [DailySample],
        current: TrainingReadiness?,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [WeeklyHeroTrendPoint] {
        let today = calendar.startOfDay(for: referenceDate)
        guard let firstDay = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }
        var latest: [Date: DailySample] = [:]
        for sample in samples {
            guard sample.date >= firstDay, sample.date <= referenceDate,
                  sample.value.isFinite, (0...100).contains(sample.value) else { continue }
            let day = calendar.startOfDay(for: sample.date)
            if let previous = latest[day], previous.date > sample.date { continue }
            latest[day] = sample
        }
        // Oldest-first. The current day must agree with the visible readiness ring.
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            let value: Int?
            if date == today {
                value = current.flatMap {
                    $0.evaluationDate <= referenceDate && calendar.isDate($0.evaluationDate, inSameDayAs: referenceDate)
                        ? $0.score : nil
                }
            } else {
                value = latest[date].map { Int($0.value.rounded()) }
            }
            return WeeklyHeroTrendPoint(date: date, value: value)
        }
    }
}
