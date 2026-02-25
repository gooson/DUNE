import SwiftUI

/// General explanation of how the fatigue scoring algorithm works.
/// Accessible from the body map header info button and the legend bar tap.
struct FatigueAlgorithmSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                overviewSection
                decayModelSection
                sleepSection
                readinessSection
                levelExplanationSection
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
            Image(systemName: "function")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("피로도 계산 방법")
                    .font(.headline)
                Text("Compound Fatigue Score")
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
            Text("최근 14일간의 운동 기록을 분석하여 각 근육의 피로 누적을 10단계로 평가합니다. 운동의 강도, 빈도, 경과 시간, 수면 질, 생체 신호를 종합적으로 반영합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Decay Model

    private var decayModelSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "chart.line.downtrend.xyaxis", title: "지수 감쇠 모델")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                formulaRow("피로 = Σ (운동 부하 × e^(-경과시간/τ))")
                bulletPoint("최근 운동일수록 피로 기여도가 높음")
                bulletPoint("시간이 지나면 자연스럽게 감소 (지수 감쇠)")
                bulletPoint("τ(타우): 근육 크기별 회복 속도 (대근육 72h, 소근육 36h)")
            }
        }
    }

    // MARK: - Sleep

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "moon.fill", title: "수면 보정")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                bulletPoint("수면 시간 7-9시간 기준으로 회복 속도 조절")
                bulletPoint("깊은 수면·REM 비율이 높으면 회복 촉진")
                bulletPoint("수면 부족 시 피로 감소가 느려짐 (τ 증가)")
                modifierExampleRow(label: "충분한 수면", value: "×1.15", color: .green)
                modifierExampleRow(label: "수면 부족", value: "×0.70", color: .orange)
            }
        }
    }

    // MARK: - Readiness

    private var readinessSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "heart.fill", title: "생체 보정 (HRV / RHR)")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                bulletPoint("HRV(심박변이도) z-score로 자율신경 상태 평가")
                bulletPoint("RHR(안정시심박수) 상승은 피로/스트레스 신호")
                bulletPoint("두 지표를 결합하여 회복 속도 보정")
                modifierExampleRow(label: "HRV 양호", value: "×1.10", color: .green)
                modifierExampleRow(label: "RHR 상승", value: "×0.85", color: .orange)
            }
        }
    }

    // MARK: - Levels

    private var levelExplanationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "flame.fill", title: "10단계 피로 레벨")

            VStack(spacing: DS.Spacing.xs) {
                levelRow(.fullyRecovered, description: "완전히 회복됨, 최고 강도 훈련 가능")
                levelRow(.wellRested, description: "충분히 회복됨, 고강도 훈련 가능")
                levelRow(.lightFatigue, description: "약간의 피로, 일반 훈련 가능")
                levelRow(.mildFatigue, description: "경미한 피로, 중강도 훈련 권장")
                levelRow(.moderateFatigue, description: "보통 피로, 가벼운 훈련 권장")
                levelRow(.notableFatigue, description: "뚜렷한 피로, 경량 훈련 또는 휴식")
                levelRow(.highFatigue, description: "높은 피로, 적극적 회복 권장")
                levelRow(.veryHighFatigue, description: "매우 높은 피로, 휴식 필요")
                levelRow(.extremeFatigue, description: "극심한 피로, 반드시 휴식")
                levelRow(.overtrained, description: "과훈련 상태, 회복에 집중")
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

    private func modifierExampleRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, DS.Spacing.sm)
    }

    private func levelRow(_ level: FatigueLevel, description: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(level.color(for: colorScheme))
                .frame(width: 12, height: 12)
            Text(level.shortLabel)
                .font(.caption2.weight(.bold).monospacedDigit())
                .frame(width: 24, alignment: .leading)
            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
