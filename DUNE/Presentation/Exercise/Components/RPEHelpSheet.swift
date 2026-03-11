import SwiftUI

/// Help sheet explaining RPE (Rate of Perceived Exertion) scale.
struct RPEHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    private static let rows: [(range: String, label: String, rir: String, color: Color)] = [
        ("6–7", String(localized: "Light"), String(localized: "3–4 reps left"), DS.Color.positive),
        ("7–8", String(localized: "Moderate"), String(localized: "2–3 reps left"), DS.Color.caution),
        ("8–9", String(localized: "Hard"), String(localized: "1–2 reps left"), .orange),
        ("9–10", String(localized: "Near Max"), String(localized: "0–1 reps left"), DS.Color.negative),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    headerSection
                    scaleSection
                    tipSection
                }
                .padding()
            }
            .navigationTitle("RPE Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("How hard was this set?")
                .font(.title3.weight(.semibold))

            Text("RPE (Rate of Perceived Exertion) measures how difficult a set felt. It helps you track intensity and plan progression.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    private var scaleSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(Self.rows, id: \.range) { row in
                HStack {
                    Text(row.range)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(row.color)
                        .frame(width: 40, alignment: .leading)

                    Text(row.label)
                        .font(.subheadline.weight(.medium))
                        .frame(width: 80, alignment: .leading)

                    Text(row.rir)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)

                    Spacer()
                }
                .padding(.vertical, DS.Spacing.xs)
                .padding(.horizontal, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(row.color.opacity(DS.Opacity.light))
                )
            }
        }
    }

    private var tipSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(DS.Color.caution)
            Text("Higher numbers mean harder sets")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .padding(.top, DS.Spacing.sm)
    }
}

#Preview("RPE Help Sheet") {
    RPEHelpSheet()
}
