import SwiftUI
import Charts

/// 3D bar-style chart visualizing training volume across muscle groups and weeks.
/// Uses Chart3D + RectangleMark to show a spatial representation of training distribution.
///
/// - X axis: Muscle Group
/// - Y axis: Volume (sets)
/// - Z axis: Week number
/// - Color: Muscle group identity
struct TrainingVolume3DView: View {
    let workoutService: WorkoutQuerying?

    @State private var volumeData: [TrainingVolumePoint] = []
    @State private var plottableData: [TrainingVolumePoint] = []
    @State private var weekRange: Int = 8
    @State private var cachedMuscleVolumes: [(key: String, value: Double)] = []

    private static let muscleCategories: [(name: String, muscles: [MuscleGroup])] = [
        ("Chest", [.chest]),
        ("Back", [.back, .lats, .traps]),
        ("Legs", [.quadriceps, .hamstrings, .calves]),
        ("Shoulders", [.shoulders]),
        ("Arms", [.biceps, .triceps, .forearms]),
        ("Core", [.core]),
        ("Glutes", [.glutes])
    ]

    private static let categoryNames: [String] = muscleCategories.map(\.name)

    var body: some View {
        VStack(spacing: 16) {
            weekRangePicker

            if plottableData.isEmpty {
                emptyChartPlaceholder
            } else {
                trainingVolumeChart
            }

            volumeSummary
        }
        .padding()
        .task(id: weekRange) {
            await loadData()
        }
    }

    // MARK: - Components

    private var trainingVolumeChart: some View {
        Chart3D(plottableData) { point in
            RectangleMark(
                x: .value("Muscle", point.muscleIndex),
                y: .value("Volume", point.volume),
                z: .value("Week", point.week)
            )
            .foregroundStyle(by: .value("Muscle", point.muscleGroup))
        }
        .chartXScale(domain: 0...Double(Self.categoryNames.count - 1))
        .chartYScale(domain: volumeDomain)
        .chartZScale(domain: 1...Double(weekRange))
        .chartXAxis {
            AxisMarks(values: Self.categoryNames.indices.map(Double.init)) { value in
                AxisValueLabel {
                    if let rawIndex = value.as(Double.self) {
                        let index = Int(rawIndex.rounded())
                        if Self.categoryNames.indices.contains(index) {
                            Text(Self.categoryNames[index])
                        }
                    }
                }
            }
        }
        .chartXAxisLabel("Muscle Group")
        .chartYAxisLabel("Volume (sets)")
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

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No training volume data")
                .font(.title3.weight(.semibold))

            Text("Complete workouts on your iPhone or Apple Watch to see training volume distribution.")
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

    private var volumeSummary: some View {
        HStack(spacing: 16) {
            ForEach(topMuscleVolumes, id: \.key) { entry in
                VStack(spacing: 4) {
                    Text(entry.key)
                        .font(.callout.bold())
                    Text("\(Int(entry.value)) sets")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var topMuscleVolumes: [(key: String, value: Double)] {
        Array(cachedMuscleVolumes.prefix(4))
    }

    private var volumeDomain: ClosedRange<Double> {
        let maxVolume = plottableData.map(\.volume).max() ?? 1
        return 0...Swift.max(maxVolume * 1.1, 1)
    }

    private static func computeMuscleVolumes(from data: [TrainingVolumePoint]) -> [(key: String, value: Double)] {
        Dictionary(grouping: data, by: \.muscleGroup)
            .mapValues { points in points.reduce(0) { $0 + $1.volume } }
            .sorted { $0.value > $1.value }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let service = workoutService else {
            (volumeData, plottableData) = ([], [])
            cachedMuscleVolumes = []
            return
        }

        let totalDays = weekRange * 7
        do {
            let workouts = try await service.fetchWorkouts(days: totalDays)
            let snapshots = workouts.compactMap(SpatialTrainingAnalyzer.snapshot(from:))

            let calendar = Calendar.current
            let now = Date()
            var points: [TrainingVolumePoint] = []
            var pointId = 0

            for weekOffset in 1...weekRange {
                let weekEnd = calendar.date(byAdding: .day, value: -(weekOffset - 1) * 7, to: now) ?? now
                let weekStart = calendar.date(byAdding: .day, value: -7, to: weekEnd) ?? weekEnd

                let weekSnapshots = snapshots.filter { $0.date >= weekStart && $0.date < weekEnd }

                for (categoryIndex, category) in Self.muscleCategories.enumerated() {
                    var categoryVolume = 0
                    for snapshot in weekSnapshots {
                        for muscle in category.muscles {
                            if snapshot.primaryMuscles.contains(muscle) {
                                categoryVolume += snapshot.completedSetCount
                            } else if snapshot.secondaryMuscles.contains(muscle) {
                                categoryVolume += max(1, snapshot.completedSetCount / 2)
                            }
                        }
                    }

                    points.append(TrainingVolumePoint(
                        id: pointId,
                        muscleGroup: category.name,
                        muscleIndex: Double(categoryIndex),
                        week: Double(weekRange - weekOffset + 1),
                        volume: Double(categoryVolume)
                    ))
                    pointId += 1
                }
            }

            let filtered = points.filter(\.isPlottable)
            (volumeData, plottableData) = (points, filtered)
            cachedMuscleVolumes = Self.computeMuscleVolumes(from: filtered)
        } catch {
            AppLogger.healthKit.error(
                "Vision training volume fetch failed: \(error.localizedDescription)"
            )
            (volumeData, plottableData) = ([], [])
            cachedMuscleVolumes = []
        }
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
