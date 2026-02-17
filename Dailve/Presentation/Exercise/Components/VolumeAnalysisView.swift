import SwiftUI
import SwiftData

struct VolumeAnalysisView: View {
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var records: [ExerciseRecord]
    @AppStorage("weeklySetGoal") private var weeklySetGoal: Int = 15

    @State private var selectedMuscle: MuscleGroup?

    private var weeklyVolume: [MuscleGroup: Int] {
        var volume = records.weeklyMuscleVolume()
        // Ensure all muscle groups have an entry for display
        for muscle in MuscleGroup.allCases {
            volume[muscle, default: 0] += 0
        }
        return volume
    }

    private var sortedMuscles: [(MuscleGroup, Int)] {
        weeklyVolume
            .sorted { $0.value > $1.value }
    }

    private var totalWeeklySets: Int {
        weeklyVolume.values.reduce(0, +)
    }

    private var trainedMuscleCount: Int {
        weeklyVolume.values.filter { $0 > 0 }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Summary cards
                summaryCards

                // Goal setting
                goalSection

                // Muscle breakdown
                muscleBreakdown

                // Balance indicator
                balanceSection
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .navigationTitle("Volume Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
            summaryCard(
                title: "Total Sets",
                value: "\(totalWeeklySets)",
                icon: "number",
                color: DS.Color.activity
            )
            summaryCard(
                title: "Muscles Hit",
                value: "\(trainedMuscleCount)/\(MuscleGroup.allCases.count)",
                icon: "figure.strengthtraining.traditional",
                color: .purple
            )
        }
        .padding(.top, DS.Spacing.sm)
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Goal

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Weekly Goal per Muscle")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Stepper("\(weeklySetGoal) sets", value: $weeklySetGoal, in: 5...30, step: 5)
                    .font(.caption)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Muscle Breakdown

    private var muscleBreakdown: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Muscle Groups")
                .font(.headline)

            ForEach(sortedMuscles, id: \.0) { muscle, volume in
                muscleRow(muscle: muscle, volume: volume)
            }
        }
    }

    private func muscleRow(muscle: MuscleGroup, volume: Int) -> some View {
        let progress = weeklySetGoal > 0 ? min(Double(volume) / Double(weeklySetGoal), 1.0) : 0
        let isSelected = selectedMuscle == muscle

        return VStack(spacing: DS.Spacing.xxs) {
            HStack {
                Image(systemName: muscle.iconName)
                    .font(.caption)
                    .foregroundStyle(barColor(progress: progress))
                    .frame(width: 20)

                Text(muscle.displayName)
                    .font(.subheadline)

                Spacer()

                Text("\(volume)/\(weeklySetGoal)")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(volume >= weeklySetGoal ? .green : .secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(progress: progress))
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(DS.Spacing.sm)
        .background(
            isSelected ? Color.secondary.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
        )
        .onTapGesture {
            withAnimation(DS.Animation.snappy) {
                selectedMuscle = isSelected ? nil : muscle
            }
        }
    }

    private func barColor(progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.5 { return DS.Color.activity }
        if progress > 0 { return .orange }
        return .secondary.opacity(0.3)
    }

    // MARK: - Balance

    private var balanceSection: some View {
        let volumes = weeklyVolume.values.filter { $0 > 0 }
        guard !volumes.isEmpty else { return AnyView(EmptyView()) }

        let avg = Double(volumes.reduce(0, +)) / Double(volumes.count)
        let maxV = volumes.max() ?? 1
        let minV = volumes.min() ?? 0
        let ratio = avg > 0 ? Double(maxV - minV) / avg : 0
        let isBalanced = ratio < 1.5

        return AnyView(
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Image(systemName: isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isBalanced ? .green : .orange)
                    Text("Training Balance")
                        .font(.subheadline.weight(.medium))
                }

                Text(isBalanced
                    ? "Your training is well-balanced across muscle groups."
                    : "Consider adding more work for undertrained muscles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !isBalanced {
                    let undertrained = sortedMuscles.suffix(3).filter { $0.1 < weeklySetGoal / 2 }
                    if !undertrained.isEmpty {
                        HStack(spacing: DS.Spacing.xs) {
                            Text("Focus on:")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            ForEach(undertrained, id: \.0) { muscle, _ in
                                Text(muscle.displayName)
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, DS.Spacing.xs)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        )
    }
}
