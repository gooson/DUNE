import SwiftUI

/// Displays the AI-generated daily summary in the evening.
struct DailyDigestCard: View {
    let digest: DailyDigest

    var body: some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                header
                summaryText
            }
        }
        .accessibilityIdentifier("dashboard-daily-digest")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "doc.text")
                .font(.caption2)
                .foregroundStyle(DS.Color.warmGlow)

            Text("Today's Summary")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Summary

    private var summaryText: some View {
        Text(digest.summary)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
