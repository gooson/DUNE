import SwiftUI

/// Displays all 4 stress levels with descriptions and highlights the current level.
struct CumulativeStressLevelGuide: View {
    let currentLevel: CumulativeStressScore.Level

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Stress Levels")
                .font(.subheadline.weight(.semibold))

            ForEach(CumulativeStressScore.Level.allCases, id: \.self) { level in
                levelRow(level)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func levelRow(_ level: CumulativeStressScore.Level) -> some View {
        let isCurrent = level == currentLevel

        return HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Circle()
                .fill(level.color)
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(level.displayName)
                        .font(.subheadline)
                        .fontWeight(isCurrent ? .bold : .medium)

                    Text(rangeLabel(for: level))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if isCurrent {
                        Text("Current")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(level.color.opacity(0.15)))
                            .foregroundStyle(level.color)
                    }
                }

                Text(guidance(for: level))
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
        .opacity(isCurrent ? 1.0 : 0.7)
        .accessibilityElement(children: .combine)
    }

    private func rangeLabel(for level: CumulativeStressScore.Level) -> String {
        switch level {
        case .low: "0–29"
        case .moderate: "30–54"
        case .elevated: "55–74"
        case .high: "75–100"
        }
    }

    private func guidance(for level: CumulativeStressScore.Level) -> String {
        switch level {
        case .low:
            String(localized: "Your body is well-recovered. A great time to push for challenging workouts or goals.")
        case .moderate:
            String(localized: "Normal stress levels. Maintain your regular routine and keep up good sleep habits.")
        case .elevated:
            String(localized: "Stress is building up. Prioritize recovery, improve sleep consistency, and consider lighter training.")
        case .high:
            String(localized: "High accumulated stress. Focus on rest, reduce training intensity, and ensure consistent sleep timing.")
        }
    }
}
