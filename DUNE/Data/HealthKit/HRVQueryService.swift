import HealthKit

protocol HRVQuerying: Sendable {
    func fetchHRVSamples(days: Int) async throws -> [HRVSample]
    func fetchRestingHeartRate(for date: Date) async throws -> Double?
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)?
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)]
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)]
}

struct HRVQueryService: HRVQuerying, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager) {
        self.manager = manager
    }

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] {
        try await manager.ensureNotDenied(for: HKQuantityType(.heartRateVariabilitySDNN))
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.heartRateVariabilitySDNN), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )

        let samples = try await manager.execute(descriptor)

        return samples.compactMap { sample in
            let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            guard value >= 1 else { return nil } // Filter out invalid SDNN < 1ms
            return HRVSample(value: value, date: sample.startDate)
        }
    }

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        try await manager.ensureNotDenied(for: HKQuantityType(.restingHeartRate))
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

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.restingHeartRate), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )

        let samples = try await manager.execute(descriptor)
        return samples.first?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
    }

    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        try await manager.ensureNotDenied(for: HKQuantityType(.restingHeartRate))
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.restingHeartRate), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )

        let samples = try await manager.execute(descriptor)
        guard let sample = samples.first else { return nil }
        let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        return (value: value, date: sample.startDate)
    }

    func fetchHRVCollection(
        start: Date,
        end: Date,
        interval: DateComponents
    ) async throws -> [(date: Date, average: Double)] {
        try await manager.ensureNotDenied(for: HKQuantityType(.heartRateVariabilitySDNN))

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.heartRateVariabilitySDNN), predicate: predicate),
            options: .discreteAverage,
            anchorDate: start,
            intervalComponents: interval
        )

        let collection = try await manager.executeStatisticsCollection(descriptor)
        let unit = HKUnit.secondUnit(with: .milli)

        var results: [(date: Date, average: Double)] = []
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            if let avg = statistics.averageQuantity()?.doubleValue(for: unit), avg >= 1 {
                results.append((date: statistics.startDate, average: avg))
            }
        }
        return results
    }

    func fetchRHRCollection(
        start: Date,
        end: Date,
        interval: DateComponents
    ) async throws -> [(date: Date, min: Double, max: Double, average: Double)] {
        try await manager.ensureNotDenied(for: HKQuantityType(.restingHeartRate))

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.restingHeartRate), predicate: predicate),
            options: [.discreteMin, .discreteMax, .discreteAverage],
            anchorDate: start,
            intervalComponents: interval
        )

        let collection = try await manager.executeStatisticsCollection(descriptor)
        let unit = HKUnit.count().unitDivided(by: .minute())

        var results: [(date: Date, min: Double, max: Double, average: Double)] = []
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            guard let avg = statistics.averageQuantity()?.doubleValue(for: unit) else { return }
            let minVal = statistics.minimumQuantity()?.doubleValue(for: unit) ?? avg
            let maxVal = statistics.maximumQuantity()?.doubleValue(for: unit) ?? avg
            results.append((date: statistics.startDate, min: minVal, max: maxVal, average: avg))
        }
        return results
    }
}
