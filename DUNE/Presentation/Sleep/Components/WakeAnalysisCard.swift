import SwiftUI

struct WakeAnalysisCard: View {
    let analysis: WakeAfterSleepOnset

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label(String(localized: "Wake Analysis"), systemImage: "moon.stars")
                    .font(.callout)
                    .foregroundStyle(DS.Color.textSecondary)

                HStack(spacing: DS.Spacing.lg) {
                    statItem(
                        value: "\(analysis.awakeningCount)",
                        label: String(localized: "Awakenings")
                    )
                    statItem(
                        value: "\(Int(analysis.totalWASOMinutes))",
                        unit: String(localized: "min"),
                        label: String(localized: "Total WASO")
                    )
                    statItem(
                        value: "\(Int(analysis.longestAwakeningMinutes))",
                        unit: String(localized: "min"),
                        label: String(localized: "Longest")
                    )
                }

                HStack {
                    Text(String(localized: "WASO Score"))
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                    Spacer()
                    Text("\(analysis.score)")
                        .font(.title3.bold())
                        .foregroundStyle(scoreColor)
                }
            }
        }
        .accessibilityIdentifier("sleep-wake-analysis-card")
    }

    private func statItem(value: String, unit: String = "", label: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var scoreColor: Color {
        switch analysis.score {
        case 80...100: DS.Color.sleep
        case 50..<80: .orange
        default: .red
        }
    }
}
