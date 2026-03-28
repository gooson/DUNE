import Foundation

protocol VitalsTimelineAnalyzing: Sendable {
    func execute(input: AnalyzeVitalsTimelineUseCase.Input) -> VitalsTimelineAnalysis
}

/// Aggregates 30-day nightly vitals into daily summaries with anomaly detection.
struct AnalyzeVitalsTimelineUseCase: VitalsTimelineAnalyzing, Sendable {

    struct Input: Sendable {
        let heartRateSamples: [DaySample]
        let respiratoryRateSamples: [DaySample]
        let wristTemperatureSamples: [DaySample]
        let spO2Samples: [DaySample]

        struct DaySample: Sendable {
            let date: Date
            let values: [Double]
        }
    }

    /// Anomaly threshold in standard deviations.
    private let anomalyThreshold = 2.0

    func execute(input: Input) -> VitalsTimelineAnalysis {
        let hrTrack = buildTrack(from: input.heartRateSamples)
        let rrTrack = buildTrack(from: input.respiratoryRateSamples)
        let tempTrack = buildTrack(from: input.wristTemperatureSamples)
        let spo2Track = buildTrack(from: input.spO2Samples)

        let allTracks: [(VitalsTimelineAnalysis.VitalType, VitalsTimelineAnalysis.VitalTrack)] = [
            (.heartRate, hrTrack),
            (.respiratoryRate, rrTrack),
            (.wristTemperature, tempTrack),
            (.spO2, spo2Track),
        ]

        // Collect anomaly days across all vitals
        var anomalyMap: [Date: [VitalsTimelineAnalysis.AffectedVital]] = [:]
        for (type, track) in allTracks {
            guard let baseline = track.baseline, let sd = track.standardDeviation, sd > 0 else { continue }
            for summary in track.dailySummaries where summary.isAnomaly {
                let deviation = (summary.avg - baseline) / sd
                let direction: VitalsTimelineAnalysis.AffectedVital.Direction = deviation > 0 ? .above : .below
                anomalyMap[summary.date, default: []].append(
                    .init(type: type, deviationSigma: abs(deviation), direction: direction)
                )
            }
        }

        let anomalyDays = anomalyMap
            .map { VitalsTimelineAnalysis.AnomalyDay(date: $0.key, affectedVitals: $0.value) }
            .sorted { $0.date < $1.date }

        return VitalsTimelineAnalysis(
            heartRate: hrTrack,
            respiratoryRate: rrTrack,
            wristTemperature: tempTrack,
            spO2: spo2Track,
            anomalyDays: anomalyDays
        )
    }

    private func buildTrack(from samples: [Input.DaySample]) -> VitalsTimelineAnalysis.VitalTrack {
        let filtered = samples.filter { !$0.values.isEmpty }
        guard !filtered.isEmpty else {
            return .init(dailySummaries: [], baseline: nil, standardDeviation: nil, hasData: false)
        }

        let dailyAverages = filtered.map { sample -> Double in
            sample.values.reduce(0, +) / Double(sample.values.count)
        }

        let baseline = dailyAverages.reduce(0, +) / Double(dailyAverages.count)
        let sd = computeStdDev(dailyAverages, mean: baseline)

        let summaries = filtered.map { sample -> VitalsTimelineAnalysis.DailySummary in
            let avg = sample.values.reduce(0, +) / Double(sample.values.count)
            let minVal = sample.values.min() ?? 0
            let maxVal = sample.values.max() ?? 0
            let isAnomaly = sd > 0 && abs(avg - baseline) > anomalyThreshold * sd

            return .init(date: sample.date, avg: avg, min: minVal, max: maxVal, isAnomaly: isAnomaly)
        }

        return .init(dailySummaries: summaries, baseline: baseline, standardDeviation: sd, hasData: true)
    }

    private func computeStdDev(_ values: [Double], mean: Double) -> Double {
        guard values.count > 1 else { return 0 }
        let sumOfSquares = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
        return (sumOfSquares / Double(values.count)).squareRoot()
    }
}
