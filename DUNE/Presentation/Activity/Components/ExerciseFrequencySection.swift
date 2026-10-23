import SwiftUI

/// Displays workout type distribution as horizontal bars.
struct ExerciseFrequencySection: View {
    let summary: ExerciseMixSummary

    private var frequencies: [ExerciseFrequency] { summary.frequencies }

    var body: some View {
        if frequencies.isEmpty {
            emptyState
        } else {
            StandardCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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
                    HStack {
                        Text("Strength")
                        Spacer()
                        Text("\(summary.strength.formattedWithSeparator) / \(summary.total.formattedWithSeparator)")
                    }
                    .font(.caption.weight(.medium))
                    HStack {
                        Text("Cardio")
                        Spacer()
                        Text("\(summary.cardio.formattedWithSeparator) / \(summary.total.formattedWithSeparator)")
                    }
                    .font(.caption.weight(.medium))
                    if summary.other > 0 {
                        HStack {
                            Text("Other")
                            Spacer()
                            Text("\(summary.other.formattedWithSeparator) / \(summary.total.formattedWithSeparator)")
                        }
                        .font(.caption.weight(.medium))
                    }
                    if !summary.muscles.isEmpty {
                        Divider()
                        Text("Primary muscles · completed sets")
                            .font(.caption2)
                            .foregroundStyle(DS.Color.textSecondary)
                        ForEach(summary.muscles.prefix(3)) { share in
                            HStack {
                                Text(share.muscle.displayName)
                                Spacer()
                                Text(share.fraction, format: .percent.precision(.fractionLength(0)))
                            }
                            .font(.caption)
                        }
                    }
                    Divider()
                    ForEach(frequencies.prefix(6)) { freq in
                        frequencyRow(freq)
                    }

                    // Chevron hint
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
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

    private func localizedExerciseName(_ name: String) -> String {
        WorkoutActivityType.localizedDisplayName(forStoredTitle: name) ?? name
    }
}
