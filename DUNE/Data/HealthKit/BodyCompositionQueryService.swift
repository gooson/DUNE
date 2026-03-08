import HealthKit

struct BodyCompositionSample: Sendable {
    let value: Double
    let date: Date
    let syncIdentifier: String?

    init(value: Double, date: Date, syncIdentifier: String? = nil) {
        self.value = value
        self.date = date
        self.syncIdentifier = syncIdentifier
    }

    var isManagedByDuneSync: Bool {
        syncIdentifier?.hasPrefix(BodyCompositionWriteInput.syncIdentifierPrefix) == true
    }
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
    func fetchBodyFat(start: Date, end: Date) async throws -> [BodyCompositionSample]
    func fetchLeanBodyMass(start: Date, end: Date) async throws -> [BodyCompositionSample]
    func fetchLatestBodyFat(withinDays days: Int) async throws -> (value: Double, date: Date)?
    func fetchLatestLeanBodyMass(withinDays days: Int) async throws -> (value: Double, date: Date)?
}

struct BodyCompositionQueryService: BodyCompositionQuerying, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager) {
        self.manager = manager
    }

    func fetchWeight(days: Int) async throws -> [BodyCompositionSample] {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.weightSamples(
                start: Calendar.current.date(byAdding: .day, value: -days, to: mockData.referenceDate) ?? mockData.referenceDate,
                end: mockData.referenceDate.addingTimeInterval(1)
            )
        }
        return try await fetchQuantitySamples(
            type: HKQuantityType(.bodyMass),
            unit: .gramUnit(with: .kilo),
            days: days,
            validRange: 0...500
        )
    }

    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample] {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.bodyFatSamples(
                start: Calendar.current.date(byAdding: .day, value: -days, to: mockData.referenceDate) ?? mockData.referenceDate,
                end: mockData.referenceDate.addingTimeInterval(1)
            )
        }
        return try await fetchQuantitySamples(
            type: HKQuantityType(.bodyFatPercentage),
            unit: .percent(),
            days: days,
            valueTransform: { $0 * 100 } // HealthKit stores as 0.0-1.0
        )
    }

    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample] {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.leanBodyMassSamples(
                start: Calendar.current.date(byAdding: .day, value: -days, to: mockData.referenceDate) ?? mockData.referenceDate,
                end: mockData.referenceDate.addingTimeInterval(1)
            )
        }
        return try await fetchQuantitySamples(
            type: HKQuantityType(.leanBodyMass),
            unit: .gramUnit(with: .kilo),
            days: days,
            validRange: 0...300
        )
    }

    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.weightSamples(start: start, end: end)
        }
        return try await fetchQuantitySamples(
            type: HKQuantityType(.bodyMass),
            unit: .gramUnit(with: .kilo),
            start: start,
            end: end,
            validRange: 0...500
        )
    }

    func fetchLatestWeight(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.latestWeight(withinDays: days)
        }
        let calendar = Calendar.current
        let today = Date()
        // Search from yesterday back to `days` ago in a single query (sorted by most recent)
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: today)) ?? today
        let end = calendar.startOfDay(for: today) // exclude today (already queried separately)
        let samples = try await fetchQuantitySamples(
            type: HKQuantityType(.bodyMass),
            unit: .gramUnit(with: .kilo),
            start: start,
            end: end,
            validRange: 0...500
        )
        // samples are sorted by date descending (most recent first)
        guard let latest = samples.first else { return nil }
        return (value: latest.value, date: latest.date)
    }

    func fetchBMI(for date: Date) async throws -> Double? {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.bmi(for: date)
        }
        guard manager.isAvailable else { return nil }
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
              value > 0, value <= 100 else {
            return nil
        }
        return value
    }

    func fetchLatestBMI(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.latestBMI(withinDays: days)
        }
        let calendar = Calendar.current
        let today = Date()
        // Search from yesterday back to `days` ago in a single query
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: today)) ?? today
        let end = calendar.startOfDay(for: today) // exclude today (already queried separately)
        let samples = try await fetchQuantitySamples(
            type: HKQuantityType(.bodyMassIndex),
            unit: .count(),
            start: start,
            end: end,
            validRange: 0...100
        )
        // samples are sorted by date descending (most recent first)
        guard let latest = samples.first, latest.value > 0 else { return nil }
        return (value: latest.value, date: latest.date)
    }

    func fetchBMI(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.bmiSamples(start: start, end: end)
        }
        return try await fetchQuantitySamples(
            type: HKQuantityType(.bodyMassIndex),
            unit: .count(),
            start: start,
            end: end,
            validRange: 0...100
        )
    }

    func fetchBodyFat(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.bodyFatSamples(start: start, end: end)
        }
        return try await fetchQuantitySamples(
            type: HKQuantityType(.bodyFatPercentage),
            unit: .percent(),
            start: start,
            end: end,
            valueTransform: { $0 * 100 },
            validRange: 0...100
        )
    }

    func fetchLeanBodyMass(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.leanBodyMassSamples(start: start, end: end)
        }
        return try await fetchQuantitySamples(
            type: HKQuantityType(.leanBodyMass),
            unit: .gramUnit(with: .kilo),
            start: start,
            end: end,
            validRange: 0...300
        )
    }

    func fetchLatestBodyFat(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.latestBodyFat(withinDays: days)
        }
        let samples = try await fetchBodyFat(days: days)
        // fetchBodyFat returns newest first; value already * 100 (0-100%)
        guard let latest = samples.first,
              latest.value > 0, latest.value <= 100 else { return nil }
        return (value: latest.value, date: latest.date)
    }

    func fetchLatestLeanBodyMass(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.latestLeanBodyMass(withinDays: days)
        }
        let samples = try await fetchLeanBodyMass(days: days)
        // Newest first; validate 0-300 kg range
        guard let latest = samples.first,
              latest.value > 0, latest.value <= 300 else { return nil }
        return (value: latest.value, date: latest.date)
    }

    // MARK: - Private

    private func fetchQuantitySamples(
        type: HKQuantityType,
        unit: HKUnit,
        days: Int,
        valueTransform: @Sendable (Double) -> Double = { $0 },
        validRange: ClosedRange<Double>? = nil
    ) async throws -> [BodyCompositionSample] {
        guard manager.isAvailable else { return [] }
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }
        return try await fetchQuantitySamples(
            type: type, unit: unit, start: startDate, end: endDate,
            valueTransform: valueTransform, validRange: validRange
        )
    }

    private func fetchQuantitySamples(
        type: HKQuantityType,
        unit: HKUnit,
        start: Date,
        end: Date,
        valueTransform: @Sendable (Double) -> Double = { $0 },
        validRange: ClosedRange<Double>? = nil
    ) async throws -> [BodyCompositionSample] {
        guard manager.isAvailable else { return [] }
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

        return samples.compactMap { sample -> BodyCompositionSample? in
            let value = valueTransform(sample.quantity.doubleValue(for: unit))
            if let range = validRange, !range.contains(value) { return nil }
            let syncIdentifier = sample.metadata?[HKMetadataKeySyncIdentifier] as? String
            return BodyCompositionSample(
                value: value,
                date: sample.startDate,
                syncIdentifier: syncIdentifier
            )
        }
    }
}
