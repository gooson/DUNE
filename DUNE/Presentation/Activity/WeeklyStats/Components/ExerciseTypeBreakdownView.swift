import SwiftUI

/// Horizontal bar breakdown of exercise types within the selected period.
struct ExerciseTypeBreakdownView: View {
    let exerciseTypes: [ExerciseTypeVolume]

    private var sortedTypesCache: [ExerciseTypeVolume] {
        exerciseTypes.sorted { $0.durationFraction > $1.durationFraction }
    }

    var body: some View {
        let sorted = sortedTypesCache
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Exercise Breakdown")
                .font(.subheadline.weight(.semibold))

            if sorted.isEmpty {
                Text("No exercise data for this period.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(sorted) { type in
                        typeRow(type)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Row

    private func typeRow(_ type: ExerciseTypeVolume) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: type.iconName)
                .font(.caption)
                .foregroundStyle(type.color)
                .frame(width: 20, alignment: .center)

            Text(type.displayName)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(durationLabel(type.totalDuration))
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)

            Text("\(type.sessionCount)")
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(width: 24, alignment: .trailing)

            // Fraction bar
            GeometryReader { geo in
                let fraction = CGFloat(type.durationFraction)
                Capsule()
                    .fill(type.color.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(type.color)
                            .frame(width: geo.size.width * fraction)
                    }
            }
            .frame(width: 60, height: 6)
            .clipShape(Capsule())

            Text(percentLabel(type.durationFraction))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds / 60.0)
        return "\(mins.formattedWithSeparator) min"
    }

    private func percentLabel(_ fraction: Double) -> String {
        let pct = Int((fraction * 100).rounded())
        return "\(pct)%"
    }
}
