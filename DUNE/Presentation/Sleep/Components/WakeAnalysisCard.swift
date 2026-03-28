import SwiftUI

struct WakeAnalysisCard: View {
    let analysis: WakeAfterSleepOnset?

    @State private var showingInfoSheet = false

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Label(String(localized: "Wake Analysis"), systemImage: "moon.stars")
                        .font(.callout)
                        .foregroundStyle(DS.Color.textSecondary)
                    Button {
                        showingInfoSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.callout)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if let analysis {
                        Text("\(analysis.score)")
                            .font(.title3.bold())
                            .foregroundStyle(scoreColor)
                    }
                }

                if let analysis {
                    if analysis.awakeningCount == 0 {
                        Text(String(localized: "No significant awakenings detected"))
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.sleep)
                    } else {
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
                    }
                } else {
                    SleepDataPlaceholder()
                }
            }
        }
        .accessibilityIdentifier("sleep-wake-analysis-card")
        .sheet(isPresented: $showingInfoSheet) {
            WASOInfoSheet()
        }
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
        guard let score = analysis?.score else { return DS.Color.textSecondary }
        switch score {
        case 80...100: return DS.Color.sleep
        case 50..<80: return .orange
        default: return .red
        }
    }
}
