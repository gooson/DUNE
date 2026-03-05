import SwiftUI
import Charts

/// 3D bar chart visualizing training volume across muscle groups and weeks.
/// Uses Chart3D + BarMark to show a spatial representation of training distribution.
///
/// - X axis: Muscle Group
/// - Y axis: Volume (kg)
/// - Z axis: Week number
/// - Color: Muscle group identity
struct TrainingVolume3DView: View {
    @State private var sampleData = TrainingVolume3DView.generateSampleData()
    @State private var weekRange: Int = 8

    var body: some View {
        VStack(spacing: 16) {
            weekRangePicker

            Chart3D {
                ForEach(sampleData) { point in
                    BarMark(
                        x: .value("Muscle", point.muscleGroup),
                        y: .value("Volume", point.volume),
                        z: .value("Week", point.week)
                    )
                    .foregroundStyle(by: .value("Muscle", point.muscleGroup))
                }
            }
            .chart3DXAxisLabel("Muscle Group")
            .chart3DYAxisLabel("Volume (kg)")
            .chart3DZAxisLabel("Week")
            .frame(minHeight: 400)

            volumeSummary
        }
        .padding()
        .onChange(of: weekRange) { _, _ in
            sampleData = Self.generateSampleData()
        }
    }

    // MARK: - Components

    private var weekRangePicker: some View {
        Picker("Weeks", selection: $weekRange) {
            Text("4 Weeks").tag(4)
            Text("8 Weeks").tag(8)
            Text("12 Weeks").tag(12)
        }
        .pickerStyle(.segmented)
    }

    private var volumeSummary: some View {
        let grouped = Dictionary(grouping: sampleData, by: \.muscleGroup)
        let totalByMuscle = grouped.mapValues { points in
            points.reduce(0) { $0 + $1.volume }
        }
        let sorted = totalByMuscle.sorted { $0.value > $1.value }

        return HStack(spacing: 16) {
            ForEach(sorted.prefix(4), id: \.key) { muscle, total in
                VStack(spacing: 4) {
                    Text(muscle)
                        .font(.caption.bold())
                    Text("\(Int(total)) kg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Sample Data

    /// Generate sample training volume data.
    /// In production, this will aggregate ExerciseRecord data by MuscleGroup and week.
    private static func generateSampleData() -> [TrainingVolumePoint] {
        let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Glutes"]
        var points: [TrainingVolumePoint] = []
        var id = 0

        for week in 1...8 {
            for muscle in muscleGroups {
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
                    week: week,
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
    let week: Int
    let volume: Double
}
