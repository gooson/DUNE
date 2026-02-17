import Foundation
import Observation

/// Chart metric for progressive overload visualization
enum ProgressMetric: String, CaseIterable, Sendable {
    case maxWeight = "Max Weight"
    case totalVolume = "Volume"
    case estimatedOneRM = "Est. 1RM"
    case totalReps = "Total Reps"

    var unit: String {
        switch self {
        case .maxWeight: "kg"
        case .totalVolume: "kg"
        case .estimatedOneRM: "kg"
        case .totalReps: "reps"
        }
    }
}

@Observable
@MainActor
final class ExerciseHistoryViewModel {
    let exerciseDefinitionID: String
    let exerciseName: String

    private(set) var chartData: [ChartDataPoint] = []
    private(set) var trendLine: [ChartDataPoint] = []
    private(set) var sessions: [SessionSummary] = []
    private(set) var personalBest: Double?

    var selectedMetric: ProgressMetric = .maxWeight {
        didSet { recalculate() }
    }

    struct SessionSummary: Identifiable {
        let id: UUID
        let date: Date
        let setCount: Int
        let maxWeight: Double?
        let totalVolume: Double
        let totalReps: Int
        let estimatedOneRM: Double?
        let duration: TimeInterval
    }

    init(exerciseDefinitionID: String, exerciseName: String) {
        self.exerciseDefinitionID = exerciseDefinitionID
        self.exerciseName = exerciseName
    }

    func loadHistory(from records: [ExerciseRecord]) {
        let matching = records
            .filter { $0.exerciseDefinitionID == exerciseDefinitionID }
            .sorted { $0.date < $1.date }

        sessions = matching.map { record in
            let completed = record.completedSets
            let weights = completed.compactMap(\.weight).filter { $0 > 0 }
            let reps = completed.compactMap(\.reps)
            let maxW = weights.max()

            // Volume = sum of (weight × reps) for each set
            var totalVolume = 0.0
            for set in completed {
                if let w = set.weight, w > 0, w <= 500,
                   let r = set.reps, r > 0, r <= 1000 {
                    let vol = w * Double(r)
                    guard !vol.isNaN && !vol.isInfinite else { continue }
                    totalVolume += vol
                }
            }

            // Epley formula: 1RM = weight × (1 + reps / 30)
            var bestOneRM: Double?
            for set in completed {
                if let w = set.weight, w > 0, let r = set.reps, r > 0, r <= 30 {
                    let oneRM = w * (1.0 + Double(r) / 30.0)
                    if !oneRM.isNaN && !oneRM.isInfinite {
                        bestOneRM = max(bestOneRM ?? 0, oneRM)
                    }
                }
            }

            return SessionSummary(
                id: record.id,
                date: record.date,
                setCount: completed.count,
                maxWeight: maxW,
                totalVolume: totalVolume,
                totalReps: reps.reduce(0, +),
                estimatedOneRM: bestOneRM,
                duration: record.duration
            )
        }

        recalculate()
    }

    private func recalculate() {
        chartData = sessions.compactMap { session in
            guard let value = metricValue(for: session) else { return nil }
            return ChartDataPoint(date: session.date, value: value)
        }

        let values = chartData.map(\.value)
        personalBest = values.max()

        trendLine = computeTrendLine(from: chartData)
    }

    private func metricValue(for session: SessionSummary) -> Double? {
        switch selectedMetric {
        case .maxWeight:
            return session.maxWeight
        case .totalVolume:
            let vol = session.totalVolume
            return vol > 0 ? vol : nil
        case .estimatedOneRM:
            return session.estimatedOneRM
        case .totalReps:
            let reps = session.totalReps
            return reps > 0 ? Double(reps) : nil
        }
    }

    /// Simple linear regression trend line (2 endpoints)
    private func computeTrendLine(from data: [ChartDataPoint]) -> [ChartDataPoint] {
        guard data.count >= 2 else { return [] }
        let n = Double(data.count)
        let xs = data.map { $0.date.timeIntervalSince1970 }
        let ys = data.map(\.value)

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).map(*).reduce(0, +)
        let sumX2 = xs.map { $0 * $0 }.reduce(0, +)

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return [] }

        let m = (n * sumXY - sumX * sumY) / denominator
        let b = (sumY - m * sumX) / n

        guard !m.isNaN && !m.isInfinite && !b.isNaN && !b.isInfinite else { return [] }

        let y1 = m * xs[0] + b
        let y2 = m * xs[data.count - 1] + b

        guard !y1.isNaN && !y1.isInfinite && !y2.isNaN && !y2.isInfinite else { return [] }

        return [
            ChartDataPoint(date: data[0].date, value: y1),
            ChartDataPoint(date: data[data.count - 1].date, value: y2)
        ]
    }
}
