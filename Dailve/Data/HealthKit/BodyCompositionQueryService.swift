import HealthKit

struct BodyCompositionSample: Sendable {
    let value: Double
    let date: Date
}

protocol BodyCompositionQuerying: Sendable {
    func fetchWeight(days: Int) async throws -> [BodyCompositionSample]
    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample]
    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample]
    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample]
    func fetchLatestWeight(withinDays days: Int) async throws -> (value: Double, date: Date)?
    func fetchBMI(for date: Date) async throws -> Double?
    func fetchLatestBMI(withinDays days: Int) async throws -> (value: Double, date: Date)?
    func fetchBMI(start: Date, end: Date) async throws -> [BodyCompositionSample]
}

struct BodyCompositionQueryService: BodyCompositionQuerying, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager) {
        self.manager = manager
    }

    func fetchWeight(days: Int) async throws -> [BodyCompositionSample] {
        try await fetchQuantitySamples(
            type: HKQuantityType(.bodyMass),
            unit: .gramUnit(with: .kilo),
            days: days
        )
    }

    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample] {
        try await fetchQuantitySamples(
            type: HKQuantityType(.bodyFatPercentage),
            unit: .percent(),
            days: days,
            valueTransform: { $0 * 100 } // HealthKit stores as 0.0-1.0
        )
    }

    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample] {
        try await fetchQuantitySamples(
            type: HKQuantityType(.leanBodyMass),
            unit: .gramUnit(with: .kilo),
            days: days
        )
    }

    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        try await fetchQuantitySamples(
            type: HKQuantityType(.bodyMass),
            unit: .gramUnit(with: .kilo),
            start: start,
            end: end
        )
    }

    func fetchLatestWeight(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        let calendar = Calendar.current
        let today = Date()
        // Search from yesterday back to `days` ago in a single query (sorted by most recent)
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: today)) ?? today
        let end = calendar.startOfDay(for: today) // exclude today (already queried separately)
        let samples = try await fetchQuantitySamples(
            type: HKQuantityType(.bodyMass),
            unit: .gramUnit(with: .kilo),
            start: start,
            end: end
        )
        // samples are sorted by date descending (most recent first)
        guard let latest = samples.first else { return nil }
        return (value: latest.value, date: latest.date)
    }

    func fetchBMI(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        try await manager.ensureNotDenied(for: HKQuantityType(.bodyMassIndex))

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.bodyMassIndex), predicate: predicate),
            options: .mostRecent
        )
        let statistics = try await manager.executeStatistics(descriptor)
        guard let value = statistics?.mostRecentQuantity()?.doubleValue(for: .count()),
              value > 0 else {
            return nil
        }
        return value
    }

    func fetchLatestBMI(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        let calendar = Calendar.current
        let today = Date()
        // Search from yesterday back to `days` ago in a single query
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: today)) ?? today
        let end = calendar.startOfDay(for: today) // exclude today (already queried separately)
        let samples = try await fetchQuantitySamples(
            type: HKQuantityType(.bodyMassIndex),
            unit: .count(),
            start: start,
            end: end
        )
        // samples are sorted by date descending (most recent first)
        guard let latest = samples.first, latest.value > 0 else { return nil }
        return (value: latest.value, date: latest.date)
    }

    func fetchBMI(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        try await fetchQuantitySamples(
            type: HKQuantityType(.bodyMassIndex),
            unit: .count(),
            start: start,
            end: end
        )
    }

    // MARK: - Private

    private func fetchQuantitySamples(
        type: HKQuantityType,
        unit: HKUnit,
        days: Int,
        valueTransform: @Sendable (Double) -> Double = { $0 }
    ) async throws -> [BodyCompositionSample] {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }
        return try await fetchQuantitySamples(
            type: type, unit: unit, start: startDate, end: endDate, valueTransform: valueTransform
        )
    }

    private func fetchQuantitySamples(
        type: HKQuantityType,
        unit: HKUnit,
        start: Date,
        end: Date,
        valueTransform: @Sendable (Double) -> Double = { $0 }
    ) async throws -> [BodyCompositionSample] {
        try await manager.ensureNotDenied(for: type)

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )

        let samples = try await manager.execute(descriptor)

        return samples.map { sample in
            BodyCompositionSample(
                value: valueTransform(sample.quantity.doubleValue(for: unit)),
                date: sample.startDate
            )
        }
    }
}
