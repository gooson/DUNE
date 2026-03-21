import HealthKit

protocol WatchWearStateQuerying: Sendable {
    func hasRecentWatchHeartRateSample(startingAt startDate: Date, endingAt endDate: Date) async -> Bool
}

protocol HeartRateQuerying: Sendable {
    /// Fetch heart rate samples recorded during a specific HKWorkout, identified by UUID string.
    func fetchHeartRateSamples(forWorkoutID workoutID: String) async throws -> [HeartRateSample]
    /// Fetch downsampled heart rate summary (avg/max/min + samples) for a workout.
    func fetchHeartRateSummary(forWorkoutID workoutID: String) async throws -> HeartRateSummary
    /// Fetch the most recent heart rate sample within the given day window.
    func fetchLatestHeartRate(withinDays days: Int) async throws -> VitalSample?
    /// Fetch daily average heart rate samples for sparkline display.
    func fetchHeartRateHistory(days: Int) async throws -> [VitalSample]
    /// Fetch daily average heart rate samples within a date range (for scrollable detail charts).
    func fetchHeartRateHistory(start: Date, end: Date) async throws -> [VitalSample]
    /// Fetch period-aware average heart rate samples within a date range.
    func fetchHeartRateHistory(start: Date, end: Date, interval: DateComponents) async throws -> [VitalSample]
    /// Compute heart rate zone distribution for a workout.
    func fetchHeartRateZones(forWorkoutID workoutID: String, maxHR: Double) async throws -> [HeartRateZone]
    /// Compute heart rate recovery (HRR₁) from post-workout HR samples.
    func fetchHeartRateRecovery(forWorkoutID workoutID: String) async throws -> HeartRateRecovery?
}

extension HeartRateQuerying {
    func fetchHeartRateHistory(
        start: Date,
        end: Date,
        interval: DateComponents
    ) async throws -> [VitalSample] {
        try await fetchHeartRateHistory(start: start, end: end)
    }
}

struct HeartRateQueryService: HeartRateQuerying, WatchWearStateQuerying, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager) {
        self.manager = manager
    }

    func fetchHeartRateSamples(forWorkoutID workoutID: String) async throws -> [HeartRateSample] {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.workout(withID: workoutID)?.heartRateSamples ?? []
        }
        guard manager.isAvailable else { return [] }
        try await manager.ensureNotDenied(for: HKQuantityType(.heartRate))

        guard let uuid = UUID(uuidString: workoutID) else { return [] }

        // Fetch the HKWorkout by UUID to get its time range
        let workoutPredicate = HKQuery.predicateForObject(with: uuid)
        let workoutDescriptor = HKSampleQueryDescriptor(
            predicates: [.workout(workoutPredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )

        let workouts = try await manager.execute(workoutDescriptor)
        guard let workout = workouts.first else { return [] }

        // Query heart rate samples within the workout's time range
        let hrPredicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        let hrDescriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.heartRate), predicate: hrPredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )

        let samples = try await manager.execute(hrDescriptor)
        let unit = HKUnit.count().unitDivided(by: .minute())

        return samples.compactMap { sample in
            let bpm = sample.quantity.doubleValue(for: unit)
            return Self.validatedSample(bpm: bpm, date: sample.startDate)
        }
    }

    func fetchHeartRateSummary(forWorkoutID workoutID: String) async throws -> HeartRateSummary {
        let raw = try await fetchHeartRateSamples(forWorkoutID: workoutID)
        let downsampled = Self.downsample(raw)
        guard !downsampled.isEmpty else {
            return HeartRateSummary(average: 0, max: 0, min: 0, samples: [])
        }
        let bpms = downsampled.map(\.bpm)
        let avg = bpms.reduce(0, +) / Double(bpms.count)
        let maxBPM = bpms.max() ?? 0
        let minBPM = bpms.min() ?? 0
        guard !avg.isNaN, !avg.isInfinite else {
            return HeartRateSummary(average: 0, max: 0, min: 0, samples: downsampled)
        }
        return HeartRateSummary(average: avg, max: maxBPM, min: minBPM, samples: downsampled)
    }

    // MARK: - General Heart Rate (non-workout)

    private static let bpmUnit = HKUnit.count().unitDivided(by: .minute())
    private static let hrValidRange: ClosedRange<Double> = 20...300

    func fetchLatestHeartRate(withinDays days: Int) async throws -> VitalSample? {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.latestHeartRate(withinDays: days)
        }
        guard manager.isAvailable else { return nil }
        let quantityType = HKQuantityType(.heartRate)
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

        let value = sample.quantity.doubleValue(for: Self.bpmUnit)
        guard Self.hrValidRange.contains(value) else { return nil }

        return VitalSample(value: value, date: sample.startDate)
    }

    func hasRecentWatchHeartRateSample(startingAt startDate: Date, endingAt endDate: Date) async -> Bool {
        guard startDate < endDate else { return false }

        if let mockData = SimulatorAdvancedMockDataProvider.current(),
           let sample = mockData.latestHeartRate(withinDays: 1) {
            return sample.date >= startDate && sample.date <= endDate
        }

        guard manager.isAvailable else { return false }
        let quantityType = HKQuantityType(.heartRate)

        do {
            try await manager.ensureNotDenied(for: quantityType)
        } catch {
            return false
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: quantityType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 20
        )

        do {
            let samples = try await manager.execute(descriptor)
            return samples.contains { sample in
                let bpm = sample.quantity.doubleValue(for: Self.bpmUnit)
                guard Self.hrValidRange.contains(bpm) else { return false }
                return Self.isWatchSource(
                    productType: sample.sourceRevision.productType,
                    bundleIdentifier: sample.sourceRevision.source.bundleIdentifier
                )
            }
        } catch {
            AppLogger.notification.error(
                "[BedtimeReminder] Failed to query recent watch heart rate: \(error.localizedDescription)"
            )
            return false
        }
    }

    func fetchHeartRateHistory(days: Int) async throws -> [VitalSample] {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }
        return try await fetchHeartRateHistory(start: startDate, end: endDate)
    }

    func fetchHeartRateHistory(start: Date, end: Date) async throws -> [VitalSample] {
        try await fetchHeartRateHistory(
            start: start,
            end: end,
            interval: DateComponents(day: 1)
        )
    }

    func fetchHeartRateHistory(
        start: Date,
        end: Date,
        interval: DateComponents
    ) async throws -> [VitalSample] {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return Self.aggregateHistory(
                mockData.heartRateHistory(start: start, end: end),
                interval: interval
            )
        }
        guard start < end else { return [] }
        guard manager.isAvailable else { return [] }
        let quantityType = HKQuantityType(.heartRate)
        try await manager.ensureNotDenied(for: quantityType)

        let calendar = Calendar.current

        // Use statistics collection so detail charts can request hourly or daily buckets.
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: quantityType, predicate: predicate),
            options: .discreteAverage,
            anchorDate: Self.anchorDate(for: start, interval: interval, calendar: calendar),
            intervalComponents: interval
        )

        let collection = try await manager.executeStatisticsCollection(query)
        var results: [VitalSample] = []

        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            if let avg = stats.averageQuantity()?.doubleValue(for: Self.bpmUnit),
               Self.hrValidRange.contains(avg) {
                results.append(VitalSample(value: avg, date: stats.startDate))
            }
        }

        return results.sorted { $0.date < $1.date }
    }

    static func aggregateHistory(
        _ samples: [VitalSample],
        interval: DateComponents,
        calendar: Calendar = .current
    ) -> [VitalSample] {
        guard !samples.isEmpty else { return [] }

        let unit = aggregationUnit(for: interval)
        var grouped: [Date: [Double]] = [:]

        for sample in samples {
            let key = bucketStart(for: sample.date, unit: unit, calendar: calendar)
            grouped[key, default: []].append(sample.value)
        }

        return grouped.compactMap { date, values in
            guard !values.isEmpty else { return nil }
            let average = values.reduce(0, +) / Double(values.count)
            guard average.isFinite else { return nil }
            return VitalSample(value: average, date: date)
        }
        .sorted { $0.date < $1.date }
    }

    func fetchHeartRateZones(forWorkoutID workoutID: String, maxHR: Double) async throws -> [HeartRateZone] {
        let samples = try await fetchHeartRateSamples(forWorkoutID: workoutID)
        return HeartRateZoneCalculator.computeZones(samples: samples, maxHR: maxHR)
    }

    // MARK: - Heart Rate Recovery

    func fetchHeartRateRecovery(forWorkoutID workoutID: String) async throws -> HeartRateRecovery? {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.workout(withID: workoutID)?.heartRateRecovery
        }
        guard manager.isAvailable else { return nil }
        try await manager.ensureNotDenied(for: HKQuantityType(.heartRate))

        guard let uuid = UUID(uuidString: workoutID) else { return nil }

        let workoutPredicate = HKQuery.predicateForObject(with: uuid)
        let workoutDescriptor = HKSampleQueryDescriptor(
            predicates: [.workout(workoutPredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        let workouts = try await manager.execute(workoutDescriptor)
        guard let workout = workouts.first else { return nil }

        // Query HR samples: 60s before workout end to 120s after
        let queryStart = workout.endDate.addingTimeInterval(-60)
        let queryEnd = workout.endDate.addingTimeInterval(120)

        let hrPredicate = HKQuery.predicateForSamples(
            withStart: queryStart,
            end: queryEnd,
            options: .strictStartDate
        )
        let hrDescriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.heartRate), predicate: hrPredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let rawSamples = try await manager.execute(hrDescriptor)
        let unit = HKUnit.count().unitDivided(by: .minute())

        let samples: [(bpm: Double, date: Date)] = rawSamples.compactMap { sample in
            let bpm = sample.quantity.doubleValue(for: unit)
            guard (20...300).contains(bpm) else { return nil }
            return (bpm: bpm, date: sample.startDate)
        }

        return Self.computeRecovery(samples: samples, workoutEndDate: workout.endDate)
    }

    /// Pure computation of HRR₁ from validated samples. Extracted for testability.
    static func computeRecovery(
        samples: [(bpm: Double, date: Date)],
        workoutEndDate: Date
    ) -> HeartRateRecovery? {
        // Peak HR: max in [endDate - 60s, endDate]
        let peakCandidates = samples.filter {
            $0.date >= workoutEndDate.addingTimeInterval(-60) && $0.date <= workoutEndDate
        }
        guard let peakHR = peakCandidates.map(\.bpm).max() else { return nil }

        // Recovery HR: average in [endDate + 45s, endDate + 75s] (60s ± 15s window)
        let recoveryCandidates = samples.filter {
            $0.date >= workoutEndDate.addingTimeInterval(45) && $0.date <= workoutEndDate.addingTimeInterval(75)
        }
        guard !recoveryCandidates.isEmpty else { return nil }

        let recoveryHR = recoveryCandidates.map(\.bpm).reduce(0, +) / Double(recoveryCandidates.count)
        guard recoveryHR.isFinite, peakHR > recoveryHR else { return nil }

        return HeartRateRecovery(peakHR: peakHR, recoveryHR: recoveryHR)
    }

    // MARK: - Validation

    /// Validate BPM range (20-300) and return sample, or nil if out of range.
    /// Extracted for testability (Correction #22: HealthKit value range validation).
    static func validatedSample(bpm: Double, date: Date) -> HeartRateSample? {
        guard (20...300).contains(bpm) else { return nil }
        return HeartRateSample(bpm: bpm, date: date)
    }

    static func isWatchSource(productType: String?, bundleIdentifier: String) -> Bool {
        SleepQueryService.isWatchSource(
            productType: productType,
            bundleIdentifier: bundleIdentifier
        )
    }

    private static func anchorDate(
        for start: Date,
        interval: DateComponents,
        calendar: Calendar
    ) -> Date {
        switch aggregationUnit(for: interval) {
        case .hour, .day:
            return calendar.startOfDay(for: start)
        case .weekOfYear:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start)
            return calendar.date(from: components) ?? calendar.startOfDay(for: start)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: start)
            return calendar.date(from: components) ?? calendar.startOfDay(for: start)
        default:
            return calendar.startOfDay(for: start)
        }
    }

    private static func aggregationUnit(for interval: DateComponents) -> Calendar.Component {
        if interval.hour == 1 { return .hour }
        if interval.day == 1 { return .day }
        if interval.weekOfYear == 1 { return .weekOfYear }
        if interval.month == 1 { return .month }
        return .day
    }

    private static func bucketStart(
        for date: Date,
        unit: Calendar.Component,
        calendar: Calendar
    ) -> Date {
        if unit == .weekOfYear {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components) ?? date
        }

        return calendar.dateInterval(of: unit, for: date)?.start ?? date
    }

    // MARK: - Downsampling

    /// Downsample heart rate samples by averaging within fixed-width time buckets.
    /// Default interval is 10 seconds (~180 points for a 30-minute workout).
    static func downsample(
        _ samples: [HeartRateSample],
        intervalSeconds: TimeInterval = 10
    ) -> [HeartRateSample] {
        guard let first = samples.first, samples.count > 1 else { return samples }
        guard intervalSeconds > 0 else { return samples }

        let origin = first.date.timeIntervalSinceReferenceDate
        var buckets: [Int: (sum: Double, count: Int, midDate: Date)] = [:]

        for sample in samples {
            let elapsed = sample.date.timeIntervalSinceReferenceDate - origin
            let bucketIndex = Int(elapsed / intervalSeconds)
            if var bucket = buckets[bucketIndex] {
                bucket.sum += sample.bpm
                bucket.count += 1
                buckets[bucketIndex] = bucket
            } else {
                // Use midpoint of bucket as representative date
                let bucketStart = origin + Double(bucketIndex) * intervalSeconds
                let midDate = Date(timeIntervalSinceReferenceDate: bucketStart + intervalSeconds / 2)
                buckets[bucketIndex] = (sum: sample.bpm, count: 1, midDate: midDate)
            }
        }

        return buckets.sorted(by: { $0.key < $1.key }).map { _, bucket in
            HeartRateSample(bpm: bucket.sum / Double(bucket.count), date: bucket.midDate)
        }
    }
}
