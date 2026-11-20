import Foundation

struct TrainingLoadWeekTotals {
    let current: Double
    let previous: Double

    init?(data: [TrainingLoadDataPoint], today: Date, calendar: Calendar) {
        let day = calendar.startOfDay(for: today)
        guard let end = calendar.date(byAdding: .day, value: 1, to: day),
              let currentStart = calendar.date(byAdding: .day, value: -6, to: day),
              let previousStart = calendar.date(byAdding: .day, value: -13, to: day)
        else { return nil }

        var currentSum = 0.0
        var previousSum = 0.0
        for point in data where (previousStart..<end).contains(point.date) {
            if point.date >= currentStart {
                currentSum += point.load
            } else {
                previousSum += point.load
            }
        }
        current = currentSum
        previous = previousSum
    }
}
