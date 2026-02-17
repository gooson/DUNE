import SwiftUI

/// Compact muscle activity summary for the Activity dashboard.
/// Shows top 6 muscle groups as horizontal progress bars.
/// Tapping navigates to the full MuscleMapView.
struct MuscleMapSummaryCard: View {
    let records: [ExerciseRecord]

    private var weeklyVolume: [MuscleGroup: Int] {
        records.weeklyMuscleVolume()
    }

    private var topMuscles: [(MuscleGroup, Int)] {
        weeklyVolume
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { ($0.key, $0.value) }
    }

    private var maxVolume: Int {
        topMuscles.first?.1 ?? 1
    }

    private var hasData: Bool {
        !topMuscles.isEmpty
    }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header
                HStack {
                    Image(systemName: "figure.stand")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.activity)
                    Text("Muscle Activity")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    NavigationLink {
                        MuscleMapView()
                    } label: {
                        Text("Full Map")
                            .font(.caption)
                            .foregroundStyle(DS.Color.activity)
                    }
                }

                if hasData {
                    // Top muscles as progress bars
                    ForEach(topMuscles, id: \.0) { muscle, sets in
                        muscleRow(muscle: muscle, sets: sets)
                    }
                } else {
                    // Empty state
                    HStack {
                        Spacer()
                        VStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "figure.run")
                                .font(.title3)
                                .foregroundStyle(.quaternary)
                            Text("Start recording workouts to see muscle activity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, DS.Spacing.md)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Muscle Row

    private func muscleRow(muscle: MuscleGroup, sets: Int) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(muscle.displayName)
                .font(.caption)
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                let fraction = maxVolume > 0 ? Double(sets) / Double(maxVolume) : 0
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(DS.Color.activity.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(DS.Color.activity.gradient)
                            .frame(width: max(geo.size.width * fraction, 4))
                    }
            }
            .frame(height: 8)

            Text("\(sets) sets")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

#Preview("With Data") {
    NavigationStack {
        MuscleMapSummaryCard(records: [])
    }
    .modelContainer(for: [ExerciseRecord.self, WorkoutSet.self], inMemory: true)
}

#Preview("Empty") {
    NavigationStack {
        MuscleMapSummaryCard(records: [])
    }
    .modelContainer(for: [ExerciseRecord.self, WorkoutSet.self], inMemory: true)
}
