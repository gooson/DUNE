import SwiftUI

/// Compact sleep deficit badge for the Today tab Body section.
/// Shows a small ring gauge with deficit amount and level label.
struct SleepDeficitBadgeView: View {
    let analysis: SleepDeficitAnalysis

    // Max deficit for ring scale (10 hours in minutes)
    private let maxDeficitMinutes = 600.0

    private var progress: Double {
        min(analysis.weeklyDeficit / maxDeficitMinutes, 1.0)
    }

    var body: some View {
        StandardCard {
            HStack(spacing: DS.Spacing.md) {
                // Mini ring gauge
                ZStack {
                    Circle()
                        .stroke(levelColor.opacity(DS.Opacity.border), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(levelColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "bed.double.fill")
                            .font(.caption2)
                            .foregroundStyle(DS.Color.body)

                        Text("Sleep Debt")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text(deficitText)
                            .font(.subheadline.bold().monospacedDigit())

                        Text(levelLabel)
                            .font(.caption2)
                            .foregroundStyle(levelColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(levelColor.opacity(0.12), in: Capsule())
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Computed

    private var deficitText: String {
        let hours = Int(analysis.weeklyDeficit) / 60
        let mins = Int(analysis.weeklyDeficit) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    private var levelColor: Color {
        switch analysis.level {
        case .good: DS.Color.scoreGood
        case .mild: DS.Color.scoreFair
        case .moderate: DS.Color.scoreTired
        case .severe: DS.Color.scoreWarning
        case .insufficient: DS.Color.textTertiary
        }
    }

    private var levelLabel: String {
        switch analysis.level {
        case .good: String(localized: "Well Rested")
        case .mild: String(localized: "Slightly Short")
        case .moderate: String(localized: "Sleep Debt")
        case .severe: String(localized: "Severe Debt")
        case .insufficient: String(localized: "Collecting Data")
        }
    }
}
