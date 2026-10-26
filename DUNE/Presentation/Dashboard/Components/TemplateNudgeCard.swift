import SwiftUI

/// Dashboard card that nudges users to save a detected workout pattern as a reusable template.
struct TemplateNudgeCard: View {
    let recommendation: WorkoutTemplateRecommendation
    let onSaveAsTemplate: () -> Void
    let onDismiss: () -> Void

    private static let tagBackground = DS.Color.activity.opacity(DS.Opacity.subtle)

    var body: some View {
        DashboardSupportCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header with dismiss
                HStack {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(DS.Color.activity)
                        Text("Your Routine")
                            .font(.subheadline.weight(.semibold))
                    }

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Dismiss"))
                    .accessibilityIdentifier("dashboard-template-nudge-dismiss")
                }

                // Exercise list
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    ForEach(recommendation.sequenceLabels.prefix(4), id: \.self) { label in
                        HStack(spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(Self.tagBackground)
                                .frame(width: 5, height: 5)
                            Text(label)
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }

                // Reasoning
                Text(summaryText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                // CTA
                Button(action: onSaveAsTemplate) {
                    Label("Save as Template", systemImage: "bookmark.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DS.Color.onActivity)
                .controlSize(.small)
                .tint(DS.Color.activity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard-template-nudge-card")
    }

    private var summaryText: String {
        let mins = Int(recommendation.averageDurationMinutes)
        return String(localized: "Repeated \(recommendation.frequency) times, avg \(mins) min")
    }
}
