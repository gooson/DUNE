import SwiftUI

/// Transparent breakdown of how a muscle's fatigue level was calculated.
struct FatigueInfoSheet: View {
    let score: CompoundFatigueScore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                workoutContributionsSection
                sleepModifierSection
                readinessModifierSection
                Divider()
                resultSection
                FatigueLegendView()
                    .padding(.top, DS.Spacing.sm)
            }
            .padding(DS.Spacing.xl)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("피로도 계산 방법")
                    .font(.headline)
                HStack(spacing: DS.Spacing.xs) {
                    Text(score.muscle.displayName)
                        .font(.subheadline)
                    Text(score.level.shortLabel)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(score.level.color(for: colorScheme).opacity(0.15), in: Capsule())
                        .foregroundStyle(score.level.color(for: colorScheme))
                }
            }
            Spacer()
        }
    }

    // MARK: - Workout Contributions

    private var workoutContributionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "chart.bar.fill", title: "운동 부하 (14일)")

            if score.breakdown.workoutContributions.isEmpty {
                Text("운동 기록 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(score.breakdown.workoutContributions) { contribution in
                    contributionRow(contribution)
                }

                HStack {
                    Text("소계")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(score.breakdown.baseFatigue.formattedWithSeparator(fractionDigits: 2))
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                .padding(.top, DS.Spacing.xxs)
            }
        }
    }

    private func contributionRow(_ contribution: WorkoutContribution) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(Self.dateFormatter.string(from: contribution.date))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 45, alignment: .leading)

            Text(contribution.exerciseName ?? "Unknown")
                .font(.caption)
                .lineLimit(1)

            Spacer()

            HStack(spacing: DS.Spacing.xxs) {
                Text(contribution.rawLoad.formattedWithSeparator(fractionDigits: 1))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(contribution.decayedLoad.formattedWithSeparator(fractionDigits: 2))
                    .font(.caption2.weight(.medium).monospacedDigit())
            }
        }
    }

    // MARK: - Sleep Modifier

    private var sleepModifierSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "moon.fill", title: "수면 보정")

            HStack {
                Text("보정 계수")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("×\(score.breakdown.sleepModifier.formattedWithSeparator(fractionDigits: 2))")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(modifierColor(score.breakdown.sleepModifier))
            }

            if score.breakdown.sleepModifier == 1.0 {
                Text("수면 데이터 미수집 — 기본값 적용")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Readiness Modifier

    private var readinessModifierSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "heart.fill", title: "생체 보정")

            HStack {
                Text("보정 계수")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("×\(score.breakdown.readinessModifier.formattedWithSeparator(fractionDigits: 2))")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(modifierColor(score.breakdown.readinessModifier))
            }

            if score.breakdown.readinessModifier == 1.0 {
                Text("HRV/RHR 데이터 미수집 — 기본값 적용")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Result

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("최종 피로도")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: DS.Spacing.xs) {
                    Text(score.normalizedScore.formattedWithSeparator(fractionDigits: 2))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(score.level.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(score.level.color(for: colorScheme))
                }
            }

            HStack {
                Text("감쇠 시간 상수 (τ)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(score.breakdown.effectiveTau.formattedWithSeparator())h")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func modifierColor(_ value: Double) -> Color {
        if value > 1.0 { return .green }
        if value < 1.0 { return .orange }
        return .secondary
    }

    private enum Cache {
        static let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "M/d"
            return f
        }()
    }

    private static var dateFormatter: DateFormatter { Cache.dateFormatter }
}
