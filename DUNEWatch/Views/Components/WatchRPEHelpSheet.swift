import SwiftUI

/// Compact RPE help sheet for watchOS.
struct WatchRPEHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    private static let rows: [(range: String, label: String, rir: String, color: Color)] = [
        ("6–7", String(localized: "Light"), String(localized: "3–4 left"), DS.Color.positive),
        ("7–8", String(localized: "Moderate"), String(localized: "2–3 left"), DS.Color.caution),
        ("8–9", String(localized: "Hard"), String(localized: "1–2 left"), .orange),
        ("9–10", String(localized: "Near Max"), String(localized: "0–1 left"), DS.Color.negative),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("How hard was this set?")
                    .font(.headline)

                ForEach(Self.rows, id: \.range) { row in
                    HStack(spacing: DS.Spacing.xs) {
                        Text(row.range)
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(row.color)
                            .frame(width: 32, alignment: .leading)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.label)
                                .font(.caption2.weight(.medium))
                            Text(row.rir)
                                .font(.caption2)
                                .foregroundStyle(DS.Color.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, DS.Spacing.xxs)
                }

                Text("Higher numbers = harder sets")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(.top, DS.Spacing.xs)
            }
            .padding(.horizontal)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview("Watch RPE Help") {
    WatchRPEHelpSheet()
}
