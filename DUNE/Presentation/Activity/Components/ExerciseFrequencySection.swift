import SwiftUI

/// Displays workout type distribution as horizontal bars.
struct ExerciseFrequencySection: View {
    let frequencies: [ExerciseFrequency]

    var body: some View {
        if frequencies.isEmpty {
            emptyState
        } else {
            StandardCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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
                Text(freq.exerciseName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(freq.count)x")
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
                Text("Exercise distribution will appear after a few workouts.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
        }
    }
}
