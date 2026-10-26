import SwiftUI

/// Displays workout type distribution as horizontal bars.
struct ExerciseFrequencySection: View {
    let summary: ExerciseMixSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var frequencies: [ExerciseFrequency] { summary.frequencies }

    var body: some View {
        if summary.total == 0 && frequencies.isEmpty {
            emptyState
        } else {
            StandardCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    if summary.isHealthKitSourceUnavailable { partialDataNotice }
                    Text("Last 28 days · by recorded exercise entries")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                    ViewThatFits(in: .horizontal) {
                        if !dynamicTypeSize.isAccessibilitySize {
                            HStack(alignment: .top, spacing: DS.Spacing.md) {
                                categoryMetric("Strength", icon: "dumbbell.fill", count: summary.strength, color: DS.Color.activityStrength)
                                categoryMetric("Cardio", icon: "figure.run", count: summary.cardio, color: DS.Color.activityCardio)
                            }
                        }
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            categoryMetric("Strength", icon: "dumbbell.fill", count: summary.strength, color: DS.Color.activityStrength)
                            categoryMetric("Cardio", icon: "figure.run", count: summary.cardio, color: DS.Color.activityCardio)
                        }
                    }
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            DS.Color.activityStrength
                                .frame(width: geometry.size.width * CGFloat(summary.strength) / CGFloat(max(summary.total, 1)))
                            DS.Color.activityCardio
                                .frame(width: geometry.size.width * CGFloat(summary.cardio) / CGFloat(max(summary.total, 1)))
                            DS.Color.activityOther
                                .frame(width: geometry.size.width * CGFloat(summary.other) / CGFloat(max(summary.total, 1)))
                        }
                    }
                    .frame(height: 16)
                    .background(DS.Color.activity.opacity(0.12), in: Capsule())
                    .clipShape(Capsule())
                    .accessibilityHidden(true)
                    if summary.other > 0 {
                        categoryMetric("Other", icon: "ellipsis.circle.fill", count: summary.other, color: DS.Color.activityOther)
                    }
                    if !summary.muscles.isEmpty {
                        Divider()
                        Text("Primary muscles · completed sets")
                            .font(.caption2)
                            .foregroundStyle(DS.Color.textSecondary)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: DS.Spacing.xs) {
                                muscleChips
                            }
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                muscleChips
                            }
                        }
                    }
                    if !frequencies.isEmpty {
                        Divider()
                        ForEach(frequencies.prefix(6)) { freq in
                            frequencyRow(freq)
                        }
                    }

                }
            }
        }
    }

    private func categoryMetric(_ title: LocalizedStringKey, icon: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(Double(count) / Double(max(summary.total, 1)), format: .percent.precision(.fractionLength(0)))
                .font(DS.Typography.cardScore)
                .foregroundStyle(color)
                .monospacedDigit()
            Text("\(count.formattedWithSeparator) / \(summary.total.formattedWithSeparator)")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var muscleChips: some View {
        ForEach(summary.muscles.prefix(3)) { share in
            HStack(spacing: DS.Spacing.xs) {
                Text(share.muscle.displayName)
                Text(share.fraction, format: .percent.precision(.fractionLength(0)))
                    .foregroundStyle(DS.Color.textSecondary)
                    .monospacedDigit()
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Color.activity.opacity(0.10), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    private func frequencyRow(_ freq: ExerciseFrequency) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack {
                Text(localizedExerciseName(freq.exerciseName))
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(freq.count.formattedWithSeparator)x")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .monospacedDigit()
            }

            // Bar
            GeometryReader { geo in
                Capsule()
                    .fill(DS.Color.activity.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(DS.Color.activity)
                            .frame(width: geo.size.width * CGFloat(freq.percentage))
                    }
            }
            .frame(height: 4)
            .clipShape(Capsule())
        }
    }

    private var emptyState: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.sm) {
                if summary.isHealthKitSourceUnavailable { partialDataNotice }
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                Text(String(localized: "Exercise distribution will appear after a few workouts."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    private var partialDataNotice: some View {
        Label("Some workout data could not be loaded.", systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(DS.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func localizedExerciseName(_ name: String) -> String {
        WorkoutActivityType.localizedDisplayName(forStoredTitle: name) ?? name
    }
}
