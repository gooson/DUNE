import SwiftUI

/// Volume analysis section showing per-muscle breakdown, goal tracking, and balance indicator.
/// Integrated from the former standalone VolumeAnalysisView.
struct VolumeBreakdownSection: View {
    let sortedMuscleVolumes: [(muscle: MuscleGroup, volume: Int)]
    let totalWeeklySets: Int
    let trainedCount: Int
    let balanceInfo: MuscleBalanceInfo
    @Binding var weeklySetGoal: Int

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Summary cards
            summaryCards

            // Goal setting
            goalSection

            // Muscle breakdown
            muscleBreakdown

            // Balance indicator
            if !sortedMuscleVolumes.allSatisfy({ $0.volume == 0 }) {
                balanceSection
            }
        }
    }

    // MARK: - Summary

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
            summaryCard(
                title: "Total Sets",
                value: "\(totalWeeklySets.formattedWithSeparator)",
                icon: "number",
                color: DS.Color.activity
            )
            summaryCard(
                title: "Muscles Hit",
                value: "\(trainedCount)/\(MuscleGroup.allCases.count)",
                icon: "figure.strengthtraining.traditional",
                color: .purple
            )
        }
    }

    private func summaryCard(title: LocalizedStringKey, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.heroTextGradient)
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
                Stepper("\(weeklySetGoal.formattedWithSeparator) sets", value: $weeklySetGoal, in: 5...30, step: 5)
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

            ForEach(sortedMuscleVolumes, id: \.muscle) { item in
                muscleRow(muscle: item.muscle, volume: item.volume)
            }
        }
    }

    private func muscleRow(muscle: MuscleGroup, volume: Int) -> some View {
        let progress = weeklySetGoal > 0 ? min(Double(volume) / Double(weeklySetGoal), 1.0) : 0
        let bar = barColor(progress: progress)

        return VStack(spacing: DS.Spacing.xxs) {
            HStack {
                Image(systemName: muscle.iconName)
                    .font(.caption)
                    .foregroundStyle(bar)
                    .frame(width: 20)

                Text(muscle.displayName)
                    .font(.subheadline)

                Spacer()

                Text("\(volume.formattedWithSeparator)/\(weeklySetGoal.formattedWithSeparator)")
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
                        .fill(bar)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(DS.Spacing.sm)
    }

    private func barColor(progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.5 { return DS.Color.activity }
        if progress > 0 { return .orange }
        return .secondary.opacity(0.3)
    }

    // MARK: - Balance

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: balanceInfo.isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(balanceInfo.isBalanced ? .green : .orange)
                Text("Training Balance")
                    .font(.subheadline.weight(.medium))
            }

            Text(balanceInfo.isBalanced
                ? "Your training is well-balanced across muscle groups."
                : "Consider adding more work for undertrained muscles.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)

            if !balanceInfo.isBalanced && !balanceInfo.undertrainedMuscles.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Focus on:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    ForEach(balanceInfo.undertrainedMuscles, id: \.self) { muscle in
                        Text(muscle.displayName)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}
