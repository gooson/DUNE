import HealthKit

protocol HeartRateQuerying: Sendable {
    /// Fetch heart rate samples recorded during a specific HKWorkout, identified by UUID string.
    func fetchHeartRateSamples(forWorkoutID workoutID: String) async throws -> [HeartRateSample]
    /// Fetch downsampled heart rate summary (avg/max/min + samples) for a workout.
    func fetchHeartRateSummary(forWorkoutID workoutID: String) async throws -> HeartRateSummary
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
