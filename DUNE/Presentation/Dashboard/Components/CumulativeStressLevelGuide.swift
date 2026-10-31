import SwiftUI

/// Displays all 4 stress levels with descriptions and highlights the current level.
struct CumulativeStressLevelGuide: View {
    let currentLevel: CumulativeStressScore.Level
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var levelIconWidth: CGFloat = 24

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
            Image(systemName: level.iconName)
                .font(.body)
                .foregroundStyle(level.color)
                .frame(width: levelIconWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        levelHeading(level, isCurrent: isCurrent)
                    }
                } else {
                    HStack(spacing: DS.Spacing.xs) { levelHeading(level, isCurrent: isCurrent) }
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

    @ViewBuilder
    private func levelHeading(_ level: CumulativeStressScore.Level, isCurrent: Bool) -> some View {
        Text(level.displayName)
            .font(.subheadline.weight(isCurrent ? .bold : .medium))
            .fixedSize(horizontal: false, vertical: true)
        Text(rangeLabel(for: level)).font(.caption2).foregroundStyle(.tertiary)
        if isCurrent {
            Text("Current")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, DS.Spacing.xs).padding(.vertical, DS.Spacing.xxs)
                .background(Capsule().fill(level.color.opacity(0.15)))
                .foregroundStyle(level.color)
        }
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
