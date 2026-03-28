import SwiftUI

struct SleepDebtRecoveryCard: View {
    let prediction: SleepDebtRecoveryPrediction?

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label(String(localized: "Recovery Forecast"), systemImage: "arrow.trianglehead.counterclockwise")
                    .font(.callout)
                    .foregroundStyle(DS.Color.textSecondary)

                if let prediction {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("~\(prediction.estimatedRecoveryDays)")
                                .font(.title.bold())
                                .foregroundStyle(rateColor(prediction.recoveryRate))
                            Text(String(localized: "days to recover"))
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.textSecondary)
                        }

                        ProgressView(value: progressValue(prediction))
                            .tint(rateColor(prediction.recoveryRate))

                        HStack {
                            Text(String(localized: "Current debt: \(Int(prediction.currentDebtMinutes / 60))h \(Int(prediction.currentDebtMinutes.truncatingRemainder(dividingBy: 60)))m"))
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                            Spacer()
                            Text(prediction.recoveryRate.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(rateColor(prediction.recoveryRate))
                        }
                    }
                } else {
                    SleepDataPlaceholder()
                }
            }
        }
        .accessibilityIdentifier("sleep-debt-recovery-card")
    }

    private func progressValue(_ prediction: SleepDebtRecoveryPrediction) -> Double {
        guard prediction.currentDebtMinutes > 0 else { return 1.0 }
        let lastProjected = prediction.dailyProjection.last?.projectedDebtMinutes ?? 0
        return max(0, 1.0 - lastProjected / prediction.currentDebtMinutes)
    }

    private func rateColor(_ rate: SleepDebtRecoveryPrediction.RecoveryRate) -> Color {
        switch rate {
        case .fast: DS.Color.sleep
        case .moderate: .orange
        case .slow: .red
        case .extended: .red
        }
    }
}
