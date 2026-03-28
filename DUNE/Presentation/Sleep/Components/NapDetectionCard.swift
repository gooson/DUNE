import SwiftUI

struct NapDetectionCard: View {
    let analysis: NapAnalysis?

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label(String(localized: "Nap Patterns"), systemImage: "zzz")
                    .font(.callout)
                    .foregroundStyle(DS.Color.textSecondary)

                if let analysis {
                    if analysis.naps.isEmpty {
                        Text(String(localized: "No daytime naps detected"))
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.sleep)
                    } else {
                        HStack(spacing: DS.Spacing.lg) {
                            statItem(
                                value: "\(analysis.naps.count)",
                                label: String(localized: "Naps")
                            )
                            if let avg = analysis.averageDurationMinutes {
                                statItem(
                                    value: "\(Int(avg))",
                                    unit: String(localized: "min"),
                                    label: String(localized: "Avg Duration")
                                )
                            }
                            if let freq = analysis.frequencyPerWeek {
                                statItem(
                                    value: String(format: "%.1f", freq),
                                    label: String(localized: "Per Week")
                                )
                            }
                        }
                    }
                } else {
                    SleepDataPlaceholder()
                }
            }
        }
        .accessibilityIdentifier("sleep-nap-detection-card")
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
}
