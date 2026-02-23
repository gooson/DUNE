import Foundation
import Observation

/// ViewModel for the Training Readiness detail view.
/// Transforms raw 14-day HRV/RHR/Sleep data into chart-ready arrays.
@Observable
@MainActor
final class TrainingReadinessDetailViewModel {
    var readiness: TrainingReadiness?
    var readinessTrend: [ChartDataPoint] = []
    var hrvTrend: [ChartDataPoint] = []
    var rhrTrend: [ChartDataPoint] = []
    var sleepTrend: [ChartDataPoint] = []
    var isLoading = false

    /// Loads data from the parent ActivityViewModel's pre-fetched raw data.
    /// Input data is already range-validated by ActivityViewModel — no redundant filtering needed.
    func loadData(
        readiness: TrainingReadiness?,
        hrvDailyAverages: [DailySample],
        rhrDailyData: [DailySample],
        sleepDailyData: [SleepDailySample]
    ) {
        isLoading = true
        self.readiness = readiness

        // HRV trend (14 days, ms) — already filtered upstream
        hrvTrend = hrvDailyAverages
            .map { ChartDataPoint(date: $0.date, value: $0.value) }
            .sorted { $0.date < $1.date }

        // RHR trend (14 days, bpm) — already filtered upstream
        rhrTrend = rhrDailyData
            .map { ChartDataPoint(date: $0.date, value: $0.value) }
            .sorted { $0.date < $1.date }

        // Sleep trend (14 days, hours) — already clamped upstream
        sleepTrend = sleepDailyData
            .map { ChartDataPoint(date: $0.date, value: $0.minutes / 60.0) }
            .sorted { $0.date < $1.date }

        // Readiness score trend (approximate from sub-scores if available)
        readinessTrend = buildReadinessTrend(hrv: hrvTrend, rhr: rhrTrend, sleep: sleepTrend)

        isLoading = false
    }

    // MARK: - Readiness Trend Approximation

    /// Approximate scoring weights for the trend chart.
    /// NOTE: These intentionally differ from the full CalculateTrainingReadinessUseCase formula
    /// (which includes fatigue + trend components). This simplified model uses only the 3 available
    /// sub-score data sources: HRV, RHR, and Sleep.
    private enum ApproxWeights {
        static let hrv: Double = 0.4
        static let rhr: Double = 0.3
        static let sleep: Double = 0.3
    }

    /// Builds an approximate daily readiness trend from available sub-score data.
    private func buildReadinessTrend(
        hrv: [ChartDataPoint],
        rhr: [ChartDataPoint],
        sleep: [ChartDataPoint]
    ) -> [ChartDataPoint] {
        guard !hrv.isEmpty else { return [] }

        let calendar = Calendar.current

        // Use uniquingKeysWith to prevent crash on duplicate days (Correction per review)
        let hrvByDay = Dictionary(hrv.map { (calendar.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { _, last in last })
        let rhrByDay = Dictionary(rhr.map { (calendar.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { _, last in last })
        let sleepByDay = Dictionary(sleep.map { (calendar.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { _, last in last })

        // HRV baseline (mean of all available days)
        let hrvValues = hrv.map(\.value)
        let hrvMean = hrvValues.reduce(0, +) / Double(hrvValues.count)
        let hrvStdDev: Double = {
            let variance = hrvValues.map { ($0 - hrvMean) * ($0 - hrvMean) }.reduce(0, +) / Double(hrvValues.count)
            return sqrt(Swift.max(variance, 0.01))
        }()

        // RHR baseline
        let rhrValues = rhr.map(\.value)
        let rhrMean = rhrValues.isEmpty ? 0 : rhrValues.reduce(0, +) / Double(rhrValues.count)

        let allDays = Set(
            hrv.map { calendar.startOfDay(for: $0.date) }
            + rhr.map { calendar.startOfDay(for: $0.date) }
        ).sorted()

        return allDays.compactMap { day in
            guard let hrvValue = hrvByDay[day] else { return nil }

            // Simplified component scores (0-100 scale)
            let normalRange = Swift.max(hrvStdDev, 1.0)
            let hrvScore = Int(Swift.max(0, Swift.min(100, 50 + (hrvValue - hrvMean) / normalRange * 20)))

            let rhrScore: Int
            if let rhrValue = rhrByDay[day], rhrMean > 0 {
                let delta = rhrValue - rhrMean
                rhrScore = Int(Swift.max(0, Swift.min(100, 70 - delta * 5)))
            } else {
                rhrScore = 50 // Neutral fallback for days without RHR data
            }

            let sleepScore: Int
            if let sleepHours = sleepByDay[day] {
                sleepScore = Int(Swift.max(0, Swift.min(100, sleepHours / 8.0 * 80)))
            } else {
                sleepScore = 50 // Neutral fallback for days without sleep data
            }

            // Weighted average using simplified 3-component model
            let score = Double(hrvScore) * ApproxWeights.hrv
                      + Double(rhrScore) * ApproxWeights.rhr
                      + Double(sleepScore) * ApproxWeights.sleep
            guard score.isFinite && !score.isNaN else { return nil }

            return ChartDataPoint(date: day, value: Swift.max(0, Swift.min(100, score)))
        }
    }
}
