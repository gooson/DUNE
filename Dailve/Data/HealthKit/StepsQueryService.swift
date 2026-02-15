import HealthKit

struct StepsQueryService: Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager = .shared) {
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
}
