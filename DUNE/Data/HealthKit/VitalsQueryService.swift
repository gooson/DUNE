import HealthKit

struct VitalSample: Sendable {
    let value: Double
    let date: Date
}

protocol VitalsQuerying: Sendable {
    // MARK: - Latest values

    func fetchLatestSpO2(withinDays days: Int) async throws -> VitalSample?
    func fetchLatestRespiratoryRate(withinDays days: Int) async throws -> VitalSample?
    func fetchLatestVO2Max(withinDays days: Int) async throws -> VitalSample?
    func fetchLatestHeartRateRecovery(withinDays days: Int) async throws -> VitalSample?
    func fetchLatestWristTemperature(withinDays days: Int) async throws -> VitalSample?

    // MARK: - Collections (for sparklines and detail charts)

    func fetchSpO2Collection(days: Int) async throws -> [VitalSample]
    func fetchRespiratoryRateCollection(days: Int) async throws -> [VitalSample]
    func fetchVO2MaxHistory(days: Int) async throws -> [VitalSample]
    func fetchHeartRateRecoveryHistory(days: Int) async throws -> [VitalSample]
    func fetchWristTemperatureCollection(days: Int) async throws -> [VitalSample]

    // MARK: - Computed

    func fetchWristTemperatureBaseline(days: Int) async throws -> Double?
}

struct VitalsQueryService: VitalsQuerying, Sendable {
    private let manager: HealthKitManager

    // MARK: - Units (cached per Correction #80)

    private static let percentUnit = HKUnit.percent()
    private static let breathsPerMinUnit = HKUnit.count().unitDivided(by: .minute())
    private static let vo2MaxUnit = HKUnit.literUnit(with: .milli)
        .unitDivided(by: HKUnit.gramUnit(with: .kilo))
        .unitDivided(by: .minute())
    private static let bpmUnit = HKUnit.count().unitDivided(by: .minute())
    private static let celsiusUnit = HKUnit.degreeCelsius()

    // MARK: - Validation ranges (Correction #22, #42)

    private static let spo2Range = 0.70...1.0         // decimal percent
    private static let respRateRange = 4.0...60.0     // breaths/min
    private static let vo2MaxRange = 10.0...90.0       // ml/kg/min
    private static let hrRecoveryRange = 0.0...120.0   // bpm drop
    private static let wristTempRange = 30.0...42.0    // °C

    init(manager: HealthKitManager) {
        self.manager = manager
    }

    // MARK: - Latest values

    func fetchLatestSpO2(withinDays days: Int) async throws -> VitalSample? {
        try await fetchLatest(
            type: .oxygenSaturation,
            unit: Self.percentUnit,
            withinDays: days,
            validRange: Self.spo2Range
        )
    }

    func fetchLatestRespiratoryRate(withinDays days: Int) async throws -> VitalSample? {
        try await fetchLatest(
            type: .respiratoryRate,
            unit: Self.breathsPerMinUnit,
            withinDays: days,
            validRange: Self.respRateRange
        )
    }

    func fetchLatestVO2Max(withinDays days: Int) async throws -> VitalSample? {
        try await fetchLatest(
            type: .vo2Max,
            unit: Self.vo2MaxUnit,
            withinDays: days,
            validRange: Self.vo2MaxRange
        )
    }

    func fetchLatestHeartRateRecovery(withinDays days: Int) async throws -> VitalSample? {
        try await fetchLatest(
            type: .heartRateRecoveryOneMinute,
            unit: Self.bpmUnit,
            withinDays: days,
            validRange: Self.hrRecoveryRange
        )
    }

    func fetchLatestWristTemperature(withinDays days: Int) async throws -> VitalSample? {
        try await fetchLatest(
            type: .appleSleepingWristTemperature,
            unit: Self.celsiusUnit,
            withinDays: days,
            validRange: Self.wristTempRange
        )
    }

    // MARK: - Collections

    func fetchSpO2Collection(days: Int) async throws -> [VitalSample] {
        try await fetchCollection(
            type: .oxygenSaturation,
            unit: Self.percentUnit,
            days: days,
            validRange: Self.spo2Range
        )
    }

    func fetchRespiratoryRateCollection(days: Int) async throws -> [VitalSample] {
        try await fetchCollection(
            type: .respiratoryRate,
            unit: Self.breathsPerMinUnit,
            days: days,
            validRange: Self.respRateRange
        )
    }

    func fetchVO2MaxHistory(days: Int) async throws -> [VitalSample] {
        try await fetchCollection(
            type: .vo2Max,
            unit: Self.vo2MaxUnit,
            days: days,
            validRange: Self.vo2MaxRange
        )
    }

    func fetchHeartRateRecoveryHistory(days: Int) async throws -> [VitalSample] {
        try await fetchCollection(
            type: .heartRateRecoveryOneMinute,
            unit: Self.bpmUnit,
            days: days,
            validRange: Self.hrRecoveryRange
        )
    }

    func fetchWristTemperatureCollection(days: Int) async throws -> [VitalSample] {
        try await fetchCollection(
            type: .appleSleepingWristTemperature,
            unit: Self.celsiusUnit,
            days: days,
            validRange: Self.wristTempRange
        )
    }

    // MARK: - Computed

    func fetchWristTemperatureBaseline(days: Int = 14) async throws -> Double? {
        let samples = try await fetchCollection(
            type: .appleSleepingWristTemperature,
            unit: Self.celsiusUnit,
            days: days,
            validRange: Self.wristTempRange
        )
        guard !samples.isEmpty else { return nil }
        let sum = samples.map(\.value).reduce(0, +)
        return sum / Double(samples.count)
    }

    // MARK: - Private helpers

    private func fetchLatest(
        type identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        withinDays days: Int,
        validRange: ClosedRange<Double>
    ) async throws -> VitalSample? {
        let quantityType = HKQuantityType(identifier)
        try await manager.ensureNotDenied(for: quantityType)

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
            predicates: [.quantitySample(type: quantityType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )

        let samples = try await manager.execute(descriptor)
        guard let sample = samples.first else { return nil }

        let value = sample.quantity.doubleValue(for: unit)
        guard validRange.contains(value) else { return nil }

        return VitalSample(value: value, date: sample.startDate)
    }

    private func fetchCollection(
        type identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int,
        validRange: ClosedRange<Double>
    ) async throws -> [VitalSample] {
        let quantityType = HKQuantityType(identifier)
        try await manager.ensureNotDenied(for: quantityType)

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
            predicates: [.quantitySample(type: quantityType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )

        let samples = try await manager.execute(descriptor)

        return samples.compactMap { sample in
            let value = sample.quantity.doubleValue(for: unit)
            guard validRange.contains(value) else { return nil }
            return VitalSample(value: value, date: sample.startDate)
        }
    }
}
