import Foundation

protocol NocturnalVitalsAggregating: Sendable {
    func execute(input: AggregateNocturnalVitalsUseCase.Input) -> NocturnalVitalsSnapshot?
}

/// Aggregates raw vital samples into 5-minute buckets aligned with the sleep window.
struct AggregateNocturnalVitalsUseCase: NocturnalVitalsAggregating, Sendable {

    /// Bucket size in seconds (5 minutes).
    private let bucketInterval: TimeInterval = 5 * 60

    struct Input: Sendable {
        let sleepStart: Date
        let sleepEnd: Date
        let heartRateSamples: [TimestampedValue]
        let respiratoryRateSamples: [TimestampedValue]
        let wristTemperatureSamples: [TimestampedValue]
        let spO2Samples: [TimestampedValue]
        /// Recent baseline wrist temperature for deviation calculation.
        let wristTemperatureBaseline: Double?

        struct TimestampedValue: Sendable {
            let date: Date
            let value: Double
        }
    }

    func execute(input: Input) -> NocturnalVitalsSnapshot? {
        let duration = input.sleepEnd.timeIntervalSince(input.sleepStart)
        guard duration > 0 else { return nil }

        let bucketStarts = generateBucketStarts(from: input.sleepStart, to: input.sleepEnd)
        guard !bucketStarts.isEmpty else { return nil }

        let hrBuckets = bucketize(samples: input.heartRateSamples, bucketStarts: bucketStarts)
        let rrBuckets = bucketize(samples: input.respiratoryRateSamples, bucketStarts: bucketStarts)
        let tempBuckets = bucketize(samples: input.wristTemperatureSamples, bucketStarts: bucketStarts)
        let spo2Buckets = bucketize(samples: input.spO2Samples, bucketStarts: bucketStarts)

        let summary = buildSummary(
            hrSamples: input.heartRateSamples,
            rrSamples: input.respiratoryRateSamples,
            tempSamples: input.wristTemperatureSamples,
            spo2Samples: input.spO2Samples,
            tempBaseline: input.wristTemperatureBaseline
        )

        return NocturnalVitalsSnapshot(
            sleepStart: input.sleepStart,
            sleepEnd: input.sleepEnd,
            heartRateBuckets: hrBuckets,
            respiratoryRateBuckets: rrBuckets,
            wristTemperatureBuckets: tempBuckets,
            spO2Buckets: spo2Buckets,
            summary: summary
        )
    }

    // MARK: - Private

    private func generateBucketStarts(from start: Date, to end: Date) -> [Date] {
        var starts: [Date] = []
        var current = start
        while current < end {
            starts.append(current)
            current = current.addingTimeInterval(bucketInterval)
        }
        return starts
    }

    private func bucketize(
        samples: [Input.TimestampedValue],
        bucketStarts: [Date]
    ) -> [NocturnalVitalsSnapshot.VitalBucket] {
        guard !samples.isEmpty, !bucketStarts.isEmpty else { return [] }

        var buckets: [NocturnalVitalsSnapshot.VitalBucket] = []

        for (index, bucketStart) in bucketStarts.enumerated() {
            let bucketEnd: Date
            if index + 1 < bucketStarts.count {
                bucketEnd = bucketStarts[index + 1]
            } else {
                bucketEnd = bucketStart.addingTimeInterval(bucketInterval)
            }

            let inBucket = samples.filter { $0.date >= bucketStart && $0.date < bucketEnd }
            guard !inBucket.isEmpty else { continue }

            let values = inBucket.map(\.value)
            let avg = values.reduce(0, +) / Double(values.count)
            let minVal = values.min()!
            let maxVal = values.max()!

            buckets.append(NocturnalVitalsSnapshot.VitalBucket(
                id: bucketStart,
                avg: avg,
                min: minVal,
                max: maxVal
            ))
        }

        return buckets
    }

    private func buildSummary(
        hrSamples: [Input.TimestampedValue],
        rrSamples: [Input.TimestampedValue],
        tempSamples: [Input.TimestampedValue],
        spo2Samples: [Input.TimestampedValue],
        tempBaseline: Double?
    ) -> NocturnalVitalsSnapshot.VitalsSummary {
        let hrValues = hrSamples.map(\.value)
        let rrValues = rrSamples.map(\.value)
        let tempValues = tempSamples.map(\.value)
        let spo2Values = spo2Samples.map(\.value)

        let avgHR: Double? = hrValues.isEmpty ? nil : hrValues.reduce(0, +) / Double(hrValues.count)
        let minHR: Double? = hrValues.min()

        let avgRR: Double? = rrValues.isEmpty ? nil : rrValues.reduce(0, +) / Double(rrValues.count)

        let tempDeviation: Double?
        if let baseline = tempBaseline, !tempValues.isEmpty {
            let avgTemp = tempValues.reduce(0, +) / Double(tempValues.count)
            tempDeviation = avgTemp - baseline
        } else {
            tempDeviation = nil
        }

        let avgSpo2: Double? = spo2Values.isEmpty ? nil : spo2Values.reduce(0, +) / Double(spo2Values.count)

        return NocturnalVitalsSnapshot.VitalsSummary(
            minHeartRate: minHR,
            avgHeartRate: avgHR,
            avgRespiratoryRate: avgRR,
            wristTempDeviation: tempDeviation,
            avgSpO2: avgSpo2
        )
    }
}
