import SwiftUI

/// Displays injury risk score with level indicator and top risk factors.
struct InjuryRiskCard: View {
    let assessment: InjuryRiskAssessment?
    var weeklyStats: [ActivityStat] = []
    var streak: WorkoutStreak?
    var fatigueStates: [MuscleFatigueState] = []
    var sleepAvailable: Bool?
    var readinessAvailable: Bool?

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let gaugeTrackColor = DS.Color.activity.opacity(0.15)

    var body: some View {
        if let assessment {
            filledContent(assessment)
        } else {
            emptyState
        }
    }

    private func filledContent(_ assessment: InjuryRiskAssessment) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Score + Level
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
                    : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
                layout {
                    // Circular gauge
                    ZStack {
                        Circle()
                            .stroke(Self.gaugeTrackColor, lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: CGFloat(assessment.score) / 100.0)
                            .stroke(
                                levelColor(assessment.level),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        Text("\(assessment.score)")
                            .font(DS.Typography.cardScore)
                            .foregroundStyle(theme.heroTextGradient)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(assessment.level.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(levelColor(assessment.level))
                        Text(assessment.level.guideMessage)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                }

                if !weeklyStats.isEmpty || streak != nil || !fatigueStates.isEmpty {
                    Text("Training records · assessment context")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                    if let volume = weeklyStats.first(where: { $0.id == "volume" }) {
                        observation("Strength Volume", icon: "chart.bar.fill",
                                    value: "\(volume.value) \(volume.unit)", detail: volume.change)
                    }
                    if let streak {
                        observation("Consecutive Training", icon: "calendar",
                                    value: String(localized: "\(streak.currentStreak) days"))
                    }
                    let recovering = fatigueStates.filter { $0.weeklyVolume > 0 && !$0.isRecovered }
                    if !fatigueStates.isEmpty {
                        observation("Muscle Recovery", icon: "figure.stand",
                                    value: recovering.isEmpty ? String(localized: "Recovered") : String(localized: "Recovering"),
                                    detail: recovering.prefix(2).map { $0.muscle.displayName }.joined(separator: " · "))
                    }
                    Text("These records provide context; they are not all risk factors.")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if sleepAvailable == false {
                    Text("Sleep records are not yet included.")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                if readinessAvailable == false {
                    Text("Readiness data is unavailable.")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                // Top risk factors (max 3, pre-sorted by UseCase)
                let topFactors = Array(assessment.factors.prefix(3))

                if !topFactors.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        ForEach(topFactors, id: \.type) { factor in
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: factorIcon(factor.type))
                                    .font(.caption2)
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .frame(width: 16)
                                Text(factor.detail)
                                    .font(.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "shield.checkered")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                Text("Train for a few days to see your injury risk assessment.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    // MARK: - Helpers

    private func observation(_ title: LocalizedStringKey, icon: String, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Divider()
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func levelColor(_ level: InjuryRiskAssessment.Level) -> Color {
        switch level {
        case .low: DS.Color.positive
        case .moderate: DS.Color.caution
        case .high: .orange
        case .critical: DS.Color.negative
        }
    }

    private func factorIcon(_ type: InjuryRiskAssessment.FactorType) -> String {
        switch type {
        case .muscleFatigue: "figure.walk"
        case .consecutiveTraining: "calendar.badge.exclamationmark"
        case .volumeSpike: "chart.line.uptrend.xyaxis"
        case .sleepDeficit: "moon.zzz"
        case .activeInjury: "bandage"
        case .lowRecovery: "battery.25percent"
        case .postureIssue: "figure.stand"
        }
    }
}
