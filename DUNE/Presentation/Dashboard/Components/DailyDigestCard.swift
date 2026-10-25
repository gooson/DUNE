import SwiftUI

/// Displays a short reading of today's metrics with the complete summary on demand.
struct DailyDigestCard: View {
    let digest: DailyDigest

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsFullSummary = false

    var body: some View {
        StandardCard(padding: DS.Spacing.xxl) {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                header
                headline
                if hasRecordedMetrics {
                    metrics
                    fullSummary
                } else {
                    Text("Today's records are still being collected.")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard-daily-digest")
    }

    private var hasRecordedMetrics: Bool {
        let metrics = digest.metrics
        // Derived debt can be a zero sentinel for insufficient sleep history.
        // Only observed metrics establish that today's records are available.
        return metrics.conditionScore != nil || metrics.workoutSummary != nil
            || (metrics.sleepMinutes.map { $0.isFinite && $0 > 0 } ?? false)
            || metrics.stepsCount != nil
            || metrics.stressLevel != nil
    }

    private var header: some View {
        Label("Today's Summary", systemImage: "doc.text")
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private var headline: some View {
        Text(digest.date, format: .dateTime.month(.abbreviated).day())
            .font(.subheadline)
            .foregroundStyle(DS.Color.textSecondary)
    }

    @ViewBuilder
    private var metrics: some View {
        if digest.metrics.conditionScore != nil || digest.metrics.stepsCount != nil {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        metricContent
                    }
                } else {
                    HStack(alignment: .top, spacing: DS.Spacing.xl) {
                        metricContent
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var metricContent: some View {
        if let score = digest.metrics.conditionScore {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Condition")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)

                Text(score.formattedWithSeparator)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()

                if let delta = digest.metrics.conditionDelta {
                    Text("From yesterday: \(Double(delta).formattedWithSeparator(alwaysShowSign: true))")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("dashboard-digest-condition")
        }

        if let steps = digest.metrics.stepsCount {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Steps")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)

                Text(steps.formattedWithSeparator)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()

                Text("Recorded today")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("dashboard-digest-steps")
        }
    }

    private var fullSummary: some View {
        DisclosureGroup(isExpanded: $showsFullSummary) {
            Text(digest.summary)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.Spacing.sm)
                .accessibilityIdentifier("dashboard-digest-full-summary")
        } label: {
            Text("Full summary")
                .font(.subheadline.weight(.medium))
                .accessibilityIdentifier("dashboard-digest-summary-toggle")
        }
        .tint(DS.Color.warmGlow)
    }
}

#Preview {
    DailyDigestCard(digest: DailyDigest(
        summary: "Today's condition score was 61 (-2 from yesterday). You completed a workout. 141 steps today.",
        metrics: .init(
            conditionScore: 61,
            conditionDelta: -2,
            workoutSummary: "a workout",
            sleepMinutes: nil,
            sleepDebtMinutes: nil,
            stepsCount: 141,
            stressLevel: nil
        )
    ))
    .padding()
}
