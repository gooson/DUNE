import SwiftUI

/// Displays a short reading of today's metrics with the complete summary on demand.
struct DailyDigestCard: View {
    let digest: DailyDigest

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsFullSummary = false

    var body: some View {
        StandardCard(padding: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                header
                if hasRecordedMetrics {
                    if hasPrimaryMetrics {
                        metrics
                        Divider()
                            .accessibilityHidden(true)
                    }
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

    private var hasPrimaryMetrics: Bool {
        digest.metrics.conditionScore != nil || digest.metrics.stepsCount != nil
    }

    private var header: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Spacing.sm))
        return layout {
            Label("Today's Summary", systemImage: "doc.text")
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("dashboard-digest-header")
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(digest.date, format: .dateTime.month(.abbreviated).day())
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("dashboard-digest-date")
        }
    }

    @ViewBuilder
    private var metrics: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                metricContent
            }
        } else {
            HStack(alignment: .top, spacing: DS.Spacing.lg) {
                conditionMetric
                if digest.metrics.conditionScore != nil && digest.metrics.stepsCount != nil {
                    Divider()
                        .accessibilityHidden(true)
                }
                stepsMetric
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var metricContent: some View {
        conditionMetric
        stepsMetric
    }

    @ViewBuilder
    private var conditionMetric: some View {
        if let score = digest.metrics.conditionScore {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Condition")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                Text(score.formattedWithSeparator)
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()

                if let delta = digest.metrics.conditionDelta, delta != 0 {
                    Text("From yesterday: \(Double(delta).formattedWithSeparator(alwaysShowSign: true))")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("dashboard-digest-condition")
        }
    }

    @ViewBuilder
    private var stepsMetric: some View {
        if let steps = digest.metrics.stepsCount {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Steps")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                Text(steps.formattedWithSeparator)
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("dashboard-digest-steps")
        }
    }

    @ViewBuilder
    private var fullSummary: some View {
        let text = DailyDigestSummaryText(digest.summary)
        if !text.full.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(showsFullSummary ? text.full : text.preview)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(showsFullSummary
                        ? "dashboard-digest-full-summary" : "dashboard-digest-preview")

                if text.canExpand {
                    Button {
                        withAnimation(reduceMotion ? nil : DS.Animation.snappy) {
                            showsFullSummary.toggle()
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            if showsFullSummary {
                                Text("Collapse summary")
                            } else {
                                Text("Expand summary")
                            }
                            Image(systemName: showsFullSummary ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .accessibilityHidden(true)
                            Spacer(minLength: 0)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CardNavigationButtonStyle())
                    .accessibilityValue(showsFullSummary ? Text("Expanded") : Text("Collapsed"))
                    .accessibilityIdentifier("dashboard-digest-summary-toggle")
                }
            }
        }
    }
}

/// Presentation-only excerpt; the full generated summary is never rewritten.
struct DailyDigestSummaryText: Sendable {
    let full: String
    let preview: String
    var canExpand: Bool { preview != full }

    init(_ summary: String) {
        full = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        var firstSentence: String?
        full.enumerateSubstrings(in: full.startIndex..<full.endIndex, options: .bySentences) {
            substring, _, _, stop in
            firstSentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines)
            stop = true
        }
        preview = firstSentence.flatMap { $0.isEmpty ? nil : $0 } ?? full
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
