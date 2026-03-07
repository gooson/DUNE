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
    @State private var sampleData = ConditionScatter3DView.generateSampleData(days: 30)
    @State private var selectedPeriod: ScatterPeriod = .thirtyDays

    var body: some View {
        VStack(spacing: 16) {
            periodPicker

            Chart3D {
                ForEach(sampleData) { point in
                    PointMark(
                        x: .value("HRV", point.hrv),
                        y: .value("RHR", point.rhr),
                        z: .value("Sleep", point.sleepQuality)
                    )
                    .foregroundStyle(point.conditionColor)
                    .symbolSize(point.trainingVolume > 0 ? 80 : 40)
                }
            }
            .chartXAxisLabel("HRV (ms)")
            .chartYAxisLabel("RHR (bpm)")
            .chartZAxisLabel("Sleep (%)")
            .frame(minHeight: 400)

            legend
        }
        .padding()
        .onChange(of: selectedPeriod) { _, newPeriod in
            sampleData = Self.generateSampleData(days: newPeriod.dayCount)
        }
    }

    // MARK: - Components

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(ScatterPeriod.allCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var legend: some View {
        HStack(spacing: 24) {
            legendItem(color: .green, label: "Good (80+)")
            legendItem(color: .yellow, label: "Moderate (60-79)")
            legendItem(color: .orange, label: "Fair (40-59)")
            legendItem(color: .red, label: "Poor (<40)")
        }
        .font(.caption)
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

    // MARK: - Sample Data

    /// Generate sample data for preview and development.
    /// In production, this will be replaced by actual HealthKit data
    /// from ConditionScore, HRVSample, HeartRateSummary, and SleepSummary.
    private static func generateSampleData(days: Int) -> [ConditionDataPoint] {
        (0..<days).map { day in
            let baseCondition = Double.random(in: 35...95)
            let hrv = 20 + baseCondition * 0.8 + Double.random(in: -10...10)
            let rhr = 80 - baseCondition * 0.3 + Double.random(in: -5...5)
            let sleepQuality = Swift.max(0, Swift.min(100, baseCondition + Double.random(in: -15...15)))
            let trainingVolume = Double.random(in: 0...15000)

            return ConditionDataPoint(
                id: day,
                date: Calendar.current.date(byAdding: .day, value: -day, to: .now) ?? .now,
                hrv: hrv,
                rhr: rhr,
                sleepQuality: sleepQuality,
                conditionScore: baseCondition,
                trainingVolume: trainingVolume
            )
        }
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
        case .thirtyDays: "30 Days"
        case .sixtyDays: "60 Days"
        case .ninetyDays: "90 Days"
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
