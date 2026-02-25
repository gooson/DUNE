import SwiftUI

/// Shows body score calculation breakdown, mirroring ConditionCalculationCard pattern.
struct BodyCalculationCard: View {
    let detail: BodyScoreDetail

    // Pre-compute formatted strings to avoid allocation in body (Correction #80)
    private let weightChangeText: String
    private let weightChangeLabel: String
    private let weightPointsText: String
    private let bodyFatChangeText: String
    private let bodyFatChangeLabel: String
    private let bodyFatPointsText: String
    private let baselineText: String
    private let finalScoreText: String

    init(detail: BodyScoreDetail) {
        self.detail = detail

        if let wc = detail.weightChange {
            self.weightChangeText = String(format: "%+.1f kg", wc)
            let absChange = abs(wc)
            if absChange < 0.5 {
                self.weightChangeLabel = "stable"
            } else if wc < 0 {
                self.weightChangeLabel = "losing"
            } else {
                self.weightChangeLabel = "gaining"
            }
        } else {
            self.weightChangeText = "—"
            self.weightChangeLabel = "no data"
        }
        self.weightPointsText = String(format: "%+.0f pts", detail.weightPoints)

        if let bfc = detail.bodyFatChange {
            self.bodyFatChangeText = String(format: "%+.1f %%", bfc)
            let absChange = abs(bfc)
            if absChange < 0.3 {
                self.bodyFatChangeLabel = "stable"
            } else if bfc < 0 {
                self.bodyFatChangeLabel = "losing"
            } else {
                self.bodyFatChangeLabel = "gaining"
            }
        } else {
            self.bodyFatChangeText = "—"
            self.bodyFatChangeLabel = "no data"
        }
        self.bodyFatPointsText = String(format: "%+.0f pts", detail.bodyFatPoints)

        self.baselineText = String(format: "%.0f pts", detail.baselinePoints)
        self.finalScoreText = "\(detail.finalScore)"
    }

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
                    row(label: "Baseline", value: baselineText, sub: "neutral start")

                    Divider()

                    row(label: "Weight Δ", value: weightChangeText, sub: weightChangeLabel)
                    row(label: "Weight Points", value: weightPointsText, sub: "")

                    Divider()

                    row(label: "Body Fat Δ", value: bodyFatChangeText, sub: bodyFatChangeLabel)
                    row(label: "Body Fat Points", value: bodyFatPointsText, sub: "")

                    Divider()

                    row(label: "Final Score", value: finalScoreText, sub: "clamped [0–100]")
                }
            }
        }
    }

    // MARK: - Private

    private func row(label: String, value: String, sub: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()

                if !sub.isEmpty {
                    Text(sub)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
