import HealthKit

/// Date-only, limit-one queries let history skip gaps without loading intervening samples.
protocol MetricHistoryQuerying: Sendable {
    func earliestDate(for category: HealthMetric.Category) async throws -> Date?
    func latestDate(for category: HealthMetric.Category, before end: Date) async throws -> Date?
}

struct MetricHistoryQueryService: MetricHistoryQuerying {
    private let manager: HealthKitManager

    init(manager: HealthKitManager = .shared) {
        self.manager = manager
    }

    func earliestDate(for category: HealthMetric.Category) async throws -> Date? {
        try await sampleDate(for: category, before: Date(), ascending: true)
    }

    func latestDate(for category: HealthMetric.Category, before end: Date) async throws -> Date? {
        try await sampleDate(for: category, before: end, ascending: false)
    }

    private func sampleDate(for category: HealthMetric.Category, before end: Date, ascending: Bool) async throws -> Date? {
#if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           (ProcessInfo.processInfo.arguments.contains("--uitest-long-metric-history")
            || (ProcessInfo.processInfo.arguments.contains("--uitest-long-weight-history") && category == .weight)) {
            let oldest = Date(timeIntervalSince1970: 1_293_840_000)
            return end > oldest ? (ascending ? oldest : end.addingTimeInterval(-1)) : nil
        }
#endif
        guard manager.isAvailable else { return nil }
        // Explicit half-open boundary: the next page cannot rediscover its predecessor.
        let predicate = NSPredicate(format: "%K < %@", HKSampleSortIdentifierStartDate, end as NSDate)
        let order: SortOrder = ascending ? .forward : .reverse
        switch category {
        case .sleep:
            let query = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: order)], limit: 1
            )
            return try await manager.execute(query).first?.startDate
        case .exercise:
            let query = HKSampleQueryDescriptor(
                predicates: [.workout(predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: order)], limit: 1
            )
            return try await manager.execute(query).first?.startDate
        default:
            guard let identifier = Self.quantityIdentifier(for: category) else { return nil }
            let query = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: HKQuantityType(identifier), predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: order)], limit: 1
            )
            return try await manager.execute(query).first?.startDate
        }
    }

    static func longHistoryFixtureDates(start: Date, end: Date, interval: DateComponents) -> [Date]? {
#if DEBUG && targetEnvironment(simulator)
        guard ProcessInfo.processInfo.arguments.contains("--uitesting"),
              ProcessInfo.processInfo.arguments.contains("--uitest-long-metric-history") else { return nil }
        let calendar = Calendar.current
        var date = max(calendar.startOfDay(for: start), Date(timeIntervalSince1970: 1_293_840_000))
        var dates: [Date] = []
        while date < end {
            dates.append(date)
            guard let next = calendar.date(byAdding: interval, to: date), next > date else { break }
            date = next
        }
        return dates
#else
        return nil
#endif
    }

    static func quantityIdentifier(for category: HealthMetric.Category) -> HKQuantityTypeIdentifier? {
        switch category {
        case .hrv: .heartRateVariabilitySDNN
        case .rhr: .restingHeartRate
        case .heartRate: .heartRate
        case .steps: .stepCount
        case .weight: .bodyMass
        case .bmi: .bodyMassIndex
        case .bodyFat: .bodyFatPercentage
        case .leanBodyMass: .leanBodyMass
        case .spo2: .oxygenSaturation
        case .respiratoryRate: .respiratoryRate
        case .vo2Max: .vo2Max
        case .heartRateRecovery: .heartRateRecoveryOneMinute
        case .wristTemperature: .appleSleepingWristTemperature
        case .breathingDisturbances: .appleSleepingBreathingDisturbances
        case .sleep, .exercise: nil
        }
    }
}
