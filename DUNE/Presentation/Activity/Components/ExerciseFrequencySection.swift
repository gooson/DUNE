import SwiftUI

/// Displays workout type distribution as horizontal bars.
struct ExerciseFrequencySection: View {
    let summary: ExerciseMixSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var frequencies: [ExerciseFrequency] { summary.frequencies }

    var body: some View {
        if frequencies.isEmpty {
            emptyState
        } else {
            StandardCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    if summary.isHealthKitSourceUnavailable { partialDataNotice }
                    Text("Last 4 weeks")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
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
                    .frame(height: 10)
                    .background(DS.Color.activity.opacity(0.12), in: Capsule())
                    .clipShape(Capsule())
                    .accessibilityHidden(true)
                    ratioRow("Strength", count: summary.strength)
                    ratioRow("Cardio", count: summary.cardio)
                    if summary.other > 0 {
                        ratioRow("Other", count: summary.other)
                    }
                    if !summary.muscles.isEmpty {
                        Divider()
                        Text("Primary muscles · completed sets")
                            .font(.caption2)
                            .foregroundStyle(DS.Color.textSecondary)
                        ForEach(summary.muscles.prefix(3)) { share in
                            muscleRow(share)
                        }
                    }
                    Divider()
                    ForEach(frequencies.prefix(6)) { freq in
                        frequencyRow(freq)
                    }

                }
            }
        }
    }

    private func ratioRow(_ title: LocalizedStringKey, count: Int) -> some View {
        let value = "\(count.formattedWithSeparator) / \(summary.total.formattedWithSeparator)"
        return ViewThatFits(in: .horizontal) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack {
                    Text(title)
                    Spacer(minLength: DS.Spacing.xs)
                    Text(value).monospacedDigit()
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                Text(value)
                    .foregroundStyle(DS.Color.textSecondary)
                    .monospacedDigit()
            }
        }
        .font(.caption.weight(.medium))
    }

    private func muscleRow(_ share: ExerciseMixSummary.MuscleShare) -> some View {
        ViewThatFits(in: .horizontal) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack {
                    Text(share.muscle.displayName)
                    Spacer(minLength: DS.Spacing.xs)
                    Text(share.fraction, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(share.muscle.displayName)
                Text(share.fraction, format: .percent.precision(.fractionLength(0)))
                    .foregroundStyle(DS.Color.textSecondary)
                    .monospacedDigit()
            }
        }
        .font(.caption)
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
