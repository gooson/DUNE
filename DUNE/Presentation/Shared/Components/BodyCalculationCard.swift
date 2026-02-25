import SwiftUI

/// Shows body score calculation breakdown, mirroring ConditionCalculationCard pattern.
struct BodyCalculationCard: View {
    let detail: BodyScoreDetail

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "function")
                        .foregroundStyle(.secondary)
                    Text("Body Calculation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                VStack(spacing: DS.Spacing.sm) {
                    CalculationRow(
                        label: "Baseline",
                        value: String(format: "%.0f pts", detail.baselinePoints),
                        sub: "neutral start"
                    )

                    Divider()

                    CalculationRow(
                        label: "Weight Δ",
                        value: detail.weightChange.map { String(format: "%+.1f kg", $0) } ?? "—",
                        sub: detail.weightLabel.rawValue
                    )
                    CalculationRow(
                        label: "Weight Points",
                        value: String(format: "%+.0f pts", detail.weightPoints),
                        sub: ""
                    )

                    Divider()

                    CalculationRow(
                        label: "Final Score",
                        value: "\(detail.finalScore)",
                        sub: "clamped [0–100]"
                    )
                }
            }
        }
    }
}
