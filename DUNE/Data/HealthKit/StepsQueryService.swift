import HealthKit

protocol StepsQuerying: Sendable {
    func fetchSteps(for date: Date) async throws -> Double?
    func fetchLatestSteps(withinDays days: Int) async throws -> (value: Double, date: Date)?
    func fetchStepsCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, sum: Double)]
}

struct StepsQueryService: StepsQuerying, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager) {
        self.manager = manager
    }

    func fetchSteps(for date: Date) async throws -> Double? {
        try await manager.ensureNotDenied(for: HKQuantityType(.stepCount))
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: predicate),
            options: .cumulativeSum
        )

        let statistics = try await manager.executeStatistics(descriptor)
        return statistics?.sumQuantity()?.doubleValue(for: .count())
    }

    func fetchLatestSteps(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        let calendar = Calendar.current
        let today = Date()
        // Search backwards from yesterday (today is already queried separately)
        for dayOffset in 1...days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            if let steps = try await fetchSteps(for: date), steps > 0 {
                return (value: steps, date: date)
            }
        }
        return nil
    }

    func fetchStepsCollection(
        start: Date,
        end: Date,
        interval: DateComponents
    ) async throws -> [(date: Date, sum: Double)] {
        try await manager.ensureNotDenied(for: HKQuantityType(.stepCount))

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: interval
        )

        let collection = try await manager.executeStatisticsCollection(descriptor)

        var results: [(date: Date, sum: Double)] = []
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            if let sum = statistics.sumQuantity()?.doubleValue(for: .count()), sum > 0 {
                results.append((date: statistics.startDate, sum: sum))
            }
        }
        return results
    }
}
