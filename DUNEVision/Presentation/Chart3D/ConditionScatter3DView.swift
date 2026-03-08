import SwiftUI
import Charts

/// 3D scatter chart plotting HRV × RHR × Sleep Quality.
/// Uses Chart3D + PointMark to visualize the relationship between
/// heart rate variability, resting heart rate, and sleep quality
/// across multiple days.
///
/// - X axis: HRV (ms) — higher is generally better
/// - Y axis: RHR (bpm) — lower is generally better
/// - Z axis: Sleep Quality (%) — higher is better
/// - Color: Condition grade (green = good, red = poor)
/// - Size: Training volume for that day
struct ConditionScatter3DView: View {
    let sharedHealthDataService: SharedHealthDataService?

    @State private var dataPoints: [ConditionDataPoint] = []
    @State private var plottableDataPoints: [ConditionDataPoint] = []
    @State private var selectedPeriod: ScatterPeriod = .thirtyDays

    var body: some View {
        VStack(spacing: 16) {
            periodPicker

            if plottableDataPoints.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart3D {
                    ForEach(plottableDataPoints) { point in
                        PointMark(
                            x: .value("HRV", point.hrv),
                            y: .value("RHR", point.rhr),
                            z: .value("Sleep", point.sleepQuality)
                        )
                        .foregroundStyle(point.conditionColor)
                        .symbolSize(point.trainingVolume > 0 ? 80 : 40)
                    }
                }
                .chartXScale(domain: hrvDomain)
                .chartYScale(domain: rhrDomain)
                .chartZScale(domain: sleepDomain)
                .chartXAxisLabel("HRV (ms)")
                .chartYAxisLabel("RHR (bpm)")
                .chartZAxisLabel("Sleep (%)")
                .frame(minHeight: 400)
            }

            legend
        }
        .padding()
        .accessibilityIdentifier(VisionSurfaceAccessibility.chart3DCondition)
        .task(id: selectedPeriod) {
            await loadData()
        }
    }

    // MARK: - Components

    private var hrvDomain: ClosedRange<Double> {
        Self.paddedDomain(
            for: plottableDataPoints.map(\.hrv),
            fallback: 20...100
        )
    }

    private var rhrDomain: ClosedRange<Double> {
        Self.paddedDomain(
            for: plottableDataPoints.map(\.rhr),
            fallback: 45...90
        )
    }

    private var sleepDomain: ClosedRange<Double> {
        Self.paddedDomain(
            for: plottableDataPoints.map(\.sleepQuality),
            fallback: 0...100,
            clampTo: 0...100
        )
    }

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(ScatterPeriod.allCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Condition Data")
                .font(.title3.weight(.semibold))

            Text("Condition scores, HRV, and sleep data will appear here after a few days of tracking.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 400)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var legend: some View {
        HStack(spacing: 24) {
            legendItem(color: .green, label: "Good (80+)")
            legendItem(color: .yellow, label: "Moderate (60-79)")
            legendItem(color: .orange, label: "Fair (40-59)")
            legendItem(color: .red, label: "Poor (<40)")
        }
        .font(.callout)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let service = sharedHealthDataService else {
            (dataPoints, plottableDataPoints) = ([], [])
            return
        }

        let snapshot = await service.fetchSnapshot()
        let calendar = Calendar.current
        let cutoff = calendar.date(
            byAdding: .day,
            value: -selectedPeriod.dayCount,
            to: snapshot.fetchedAt
        ) ?? snapshot.fetchedAt

        // Build daily lookups
        let hrvByDay = Dictionary(
            grouping: snapshot.hrvSamples.filter { $0.date >= cutoff },
            by: { calendar.startOfDay(for: $0.date) }
        ).mapValues { samples in
            samples.map(\.value).reduce(0, +) / Double(samples.count)
        }

        let rhrByDay = Dictionary(
            snapshot.rhrCollection.filter { $0.date >= cutoff }
                .map { (calendar.startOfDay(for: $0.date), $0.average) },
            uniquingKeysWith: { _, latest in latest }
        )

        let sleepByDay = Dictionary(
            snapshot.sleepDailyDurations.filter { $0.date >= cutoff }
                .map { (calendar.startOfDay(for: $0.date), $0.totalMinutes) },
            uniquingKeysWith: { _, latest in latest }
        )

        let scores = snapshot.recentConditionScores.filter { $0.date >= cutoff }

        var points: [ConditionDataPoint] = []
        for (index, score) in scores.enumerated() {
            let day = calendar.startOfDay(for: score.date)
            guard let hrv = hrvByDay[day], let rhr = rhrByDay[day] else { continue }

            let sleepMinutes = sleepByDay[day] ?? 0
            // Sleep quality: 8h (480min) = 100%
            let sleepQuality = sleepMinutes > 0
                ? Swift.min(100, sleepMinutes / 480.0 * 100.0)
                : 0

            points.append(ConditionDataPoint(
                id: index,
                date: score.date,
                hrv: hrv,
                rhr: rhr,
                sleepQuality: sleepQuality,
                conditionScore: Double(score.score),
                trainingVolume: 0
            ))
        }

        let filtered = points.filter(\.isPlottable)
        (dataPoints, plottableDataPoints) = (points, filtered)
    }

    // MARK: - Helpers

    private static func paddedDomain(
        for values: [Double],
        fallback: ClosedRange<Double>,
        minimumSpan: Double = 1,
        paddingRatio: Double = 0.1,
        clampTo: ClosedRange<Double>? = nil
    ) -> ClosedRange<Double> {
        let finiteValues = values.filter(\.isFinite)
        guard let minValue = finiteValues.min(),
              let maxValue = finiteValues.max() else {
            return fallback
        }

        let span = Swift.max(maxValue - minValue, minimumSpan)
        var lowerBound = minValue - span * paddingRatio
        var upperBound = maxValue + span * paddingRatio

        if let clampTo {
            lowerBound = Swift.max(clampTo.lowerBound, lowerBound)
            upperBound = Swift.min(clampTo.upperBound, upperBound)
        }

        if lowerBound >= upperBound {
            let midpoint = (minValue + maxValue) / 2
            lowerBound = midpoint - (minimumSpan / 2)
            upperBound = midpoint + (minimumSpan / 2)
        }

        return lowerBound...upperBound
    }
}

// MARK: - Models

struct ConditionDataPoint: Identifiable {
    let id: Int
    let date: Date
    let hrv: Double
    let rhr: Double
    let sleepQuality: Double
    let conditionScore: Double
    let trainingVolume: Double

    var isPlottable: Bool {
        hrv.isFinite
            && rhr.isFinite
            && sleepQuality.isFinite
            && conditionScore.isFinite
            && trainingVolume.isFinite
    }

    var conditionColor: Color {
        switch conditionScore {
        case 80...: .green
        case 60..<80: .yellow
        case 40..<60: .orange
        default: .red
        }
    }
}

enum ScatterPeriod: String, CaseIterable, Identifiable {
    case thirtyDays
    case sixtyDays
    case ninetyDays

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thirtyDays: String(localized: "30 Days")
        case .sixtyDays: String(localized: "60 Days")
        case .ninetyDays: String(localized: "90 Days")
        }
    }

    var dayCount: Int {
        switch self {
        case .thirtyDays: 30
        case .sixtyDays: 60
        case .ninetyDays: 90
        }
    }
}
