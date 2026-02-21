import HealthKit

protocol HeartRateQuerying: Sendable {
    /// Fetch heart rate samples recorded during a specific HKWorkout, identified by UUID string.
    func fetchHeartRateSamples(forWorkoutID workoutID: String) async throws -> [HeartRateSample]
    /// Fetch downsampled heart rate summary (avg/max/min + samples) for a workout.
    func fetchHeartRateSummary(forWorkoutID workoutID: String) async throws -> HeartRateSummary
    /// Fetch the most recent heart rate sample within the given day window.
    func fetchLatestHeartRate(withinDays days: Int) async throws -> VitalSample?
    /// Fetch daily average heart rate samples for sparkline display.
    func fetchHeartRateHistory(days: Int) async throws -> [VitalSample]
    /// Compute heart rate zone distribution for a workout.
    func fetchHeartRateZones(forWorkoutID workoutID: String, maxHR: Double) async throws -> [HeartRateZone]
}

struct HeartRateQueryService: HeartRateQuerying, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager) {
        self.manager = manager
    }

    func fetchHeartRateSamples(forWorkoutID workoutID: String) async throws -> [HeartRateSample] {
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

    func fetchHeartRateHistory(days: Int) async throws -> [VitalSample] {
        let quantityType = HKQuantityType(.heartRate)
        try await manager.ensureNotDenied(for: quantityType)

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }

        // Use statistics collection for daily averages (auto-dedup)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: quantityType, predicate: predicate),
            options: .discreteAverage,
            anchorDate: calendar.startOfDay(for: startDate),
            intervalComponents: interval
        )

        let collection = try await manager.executeStatisticsCollection(query)
        var results: [VitalSample] = []

        collection.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
            if let avg = stats.averageQuantity()?.doubleValue(for: Self.bpmUnit),
               Self.hrValidRange.contains(avg) {
                results.append(VitalSample(value: avg, date: stats.startDate))
            }
        }

        return results.sorted { $0.date < $1.date }
    }

    func fetchHeartRateZones(forWorkoutID workoutID: String, maxHR: Double) async throws -> [HeartRateZone] {
        let samples = try await fetchHeartRateSamples(forWorkoutID: workoutID)
        return HeartRateZoneCalculator.computeZones(samples: samples, maxHR: maxHR)
    }

    // MARK: - Validation

    /// Validate BPM range (20-300) and return sample, or nil if out of range.
    /// Extracted for testability (Correction #22: HealthKit value range validation).
    static func validatedSample(bpm: Double, date: Date) -> HeartRateSample? {
        guard (20...300).contains(bpm) else { return nil }
        return HeartRateSample(bpm: bpm, date: date)
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
