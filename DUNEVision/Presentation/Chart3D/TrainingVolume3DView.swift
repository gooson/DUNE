import SwiftUI
import Charts

/// 3D bar-style chart visualizing training volume across muscle groups and weeks.
/// Uses Chart3D + RectangleMark to show a spatial representation of training distribution.
///
/// - X axis: Muscle Group
/// - Y axis: Volume (kg)
/// - Z axis: Week number
/// - Color: Muscle group identity
struct TrainingVolume3DView: View {
    let sharedHealthDataService: SharedHealthDataService?

    @State private var sampleData = TrainingVolume3DView.generateSampleData(weeks: 8)
    @State private var weekRange: Int = 8

    private static let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Glutes"]

    var body: some View {
        VStack(spacing: 16) {
            weekRangePicker

            trainingVolumeChart

            volumeSummary
        }
        .padding()
        .onChange(of: weekRange) { _, newWeeks in
            sampleData = Self.generateSampleData(weeks: newWeeks)
        }
    }

    // MARK: - Components

    private var trainingVolumeChart: some View {
        Chart3D(plottableSampleData) { point in
            RectangleMark(
                x: .value("Muscle", point.muscleIndex),
                y: .value("Volume", point.volume),
                z: .value("Week", point.week)
            )
            .foregroundStyle(by: .value("Muscle", point.muscleGroup))
        }
        .chartXScale(domain: 0...Double(Self.muscleGroups.count - 1))
        .chartYScale(domain: volumeDomain)
        .chartZScale(domain: 1...Double(weekRange))
        .chartXAxis {
            AxisMarks(values: Self.muscleGroups.indices.map(Double.init)) { value in
                AxisValueLabel {
                    if let rawIndex = value.as(Double.self) {
                        let index = Int(rawIndex.rounded())
                        if Self.muscleGroups.indices.contains(index) {
                            Text(Self.muscleGroups[index])
                        }
                    }
                }
            }
        }
        .chartXAxisLabel("Muscle Group")
        .chartYAxisLabel("Volume (kg)")
        .chartZAxisLabel("Week")
        .frame(minHeight: 400)
    }

    private var weekRangePicker: some View {
        Picker("Weeks", selection: $weekRange) {
            Text("4 Weeks").tag(4)
            Text("8 Weeks").tag(8)
            Text("12 Weeks").tag(12)
        }
        .pickerStyle(.segmented)
    }

    private var volumeSummary: some View {
        HStack(spacing: 16) {
            ForEach(topMuscleVolumes, id: \.key) { entry in
                VStack(spacing: 4) {
                    Text(entry.key)
                        .font(.caption.bold())
                    Text("\(Int(entry.value)) kg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var topMuscleVolumes: [(key: String, value: Double)] {
        Array(sortedMuscleVolumes.prefix(4))
    }

    private var plottableSampleData: [TrainingVolumePoint] {
        sampleData.filter(\.isPlottable)
    }

    private var sortedMuscleVolumes: [(key: String, value: Double)] {
        Self.computeMuscleVolumes(from: plottableSampleData)
    }

    private var volumeDomain: ClosedRange<Double> {
        let maxVolume = plottableSampleData.map(\.volume).max() ?? 1
        return 0...Swift.max(maxVolume * 1.1, 1)
    }

    private static func computeMuscleVolumes(from data: [TrainingVolumePoint]) -> [(key: String, value: Double)] {
        Dictionary(grouping: data, by: \.muscleGroup)
            .mapValues { points in points.reduce(0) { $0 + $1.volume } }
            .sorted { $0.value > $1.value }
    }

    // MARK: - Sample Data

    /// Generate sample training volume data.
    /// In production, this will aggregate ExerciseRecord data by MuscleGroup and week.
    private static func generateSampleData(weeks: Int) -> [TrainingVolumePoint] {
        var points: [TrainingVolumePoint] = []
        var id = 0

        for week in 1...weeks {
            for (muscleIndex, muscle) in Self.muscleGroups.enumerated() {
                let baseVolume: Double
                switch muscle {
                case "Legs": baseVolume = Double.random(in: 3000...8000)
                case "Back": baseVolume = Double.random(in: 2000...6000)
                case "Chest": baseVolume = Double.random(in: 2000...5500)
                case "Shoulders": baseVolume = Double.random(in: 1000...3500)
                case "Arms": baseVolume = Double.random(in: 800...2500)
                case "Core": baseVolume = Double.random(in: 500...2000)
                case "Glutes": baseVolume = Double.random(in: 1500...4000)
                default: baseVolume = Double.random(in: 1000...3000)
                }

                // Progressive overload trend
                let progressionMultiplier = 1.0 + Double(week) * 0.02
                let volume = baseVolume * progressionMultiplier

                points.append(TrainingVolumePoint(
                    id: id,
                    muscleGroup: muscle,
                    muscleIndex: Double(muscleIndex),
                    week: Double(week),
                    volume: volume
                ))
                id += 1
            }
        }

        return points
    }
}

// MARK: - Models

struct TrainingVolumePoint: Identifiable {
    let id: Int
    let muscleGroup: String
    let muscleIndex: Double
    let week: Double
    let volume: Double

    var isPlottable: Bool {
        muscleIndex.isFinite && week.isFinite && volume.isFinite
    }
}
