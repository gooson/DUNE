import SwiftUI

/// Explanation of how weekly training volume is calculated and displayed.
/// Accessible from the volume mode info button and the volume legend tap.
struct VolumeAlgorithmSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                overviewSection
                calculationSection
                levelSection
                tipsSection
                VolumeLegendView()
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
            Image(systemName: "chart.bar.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("주간 훈련 볼륨")
                    .font(.headline)
                Text("Weekly Training Volume")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.fill", title: "개요")
            Text("최근 7일간 각 근육군에 수행한 세트 수를 집계하여 훈련 볼륨을 시각화합니다. 어떤 근육을 많이 훈련했는지, 어떤 근육이 부족한지 한눈에 파악할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Calculation

    private var calculationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "function", title: "계산 방법")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                bulletPoint("주동근(Primary): 운동의 전체 세트 수가 해당 근육에 반영")
                bulletPoint("보조근(Secondary): 세트 수의 절반이 반영 (최소 1세트)")
                bulletPoint("복합 운동(예: 스쿼트)은 여러 근육에 동시 반영")

                formulaRow("볼륨 = Σ (주동근 세트) + Σ (보조근 세트 ÷ 2)")
            }
        }
    }

    // MARK: - Levels

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "chart.bar.xaxis", title: "5단계 볼륨 레벨")

            VStack(spacing: DS.Spacing.xs) {
                ForEach(VolumeIntensity.allCases, id: \.rawValue) { level in
                    levelRow(level)
                }
            }
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "sparkles", title: "활용 팁")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                bulletPoint("회색 근육은 이번 주에 훈련하지 않은 부위입니다")
                bulletPoint("균형 잡힌 훈련을 위해 모든 근육이 색칠되도록 목표하세요")
                bulletPoint("Recovery 모드와 함께 확인하면 최적의 훈련 계획을 세울 수 있습니다")
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

    private func formulaRow(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.xs) {
            Text("·")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func levelRow(_ level: VolumeIntensity) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(level.color)
                .overlay {
                    if level == .none {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    }
                }
                .frame(width: 12, height: 12)
            Text(level.label)
                .font(.caption2.weight(.bold).monospacedDigit())
                .frame(width: 32, alignment: .leading)
            Text(level.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
