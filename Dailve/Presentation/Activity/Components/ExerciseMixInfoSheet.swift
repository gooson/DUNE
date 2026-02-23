import SwiftUI

/// Explains how exercise mix (frequency distribution) is analyzed.
struct ExerciseMixInfoSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                overviewSection
                measurementSection
                balanceSection
                tipsSection
            }
            .padding(DS.Spacing.xl)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("운동 구성")
                    .font(.headline)
                Text("Exercise Mix")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.fill", title: "개요")
            Text("어떤 운동을 얼마나 자주 수행하는지 분석합니다. 운동 구성의 균형을 확인하고 부족한 부위를 발견하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "chart.bar.fill", title: "측정 방식")
            bulletPoint("전체 기록 중 운동별 수행 횟수를 집계")
            bulletPoint("비율(%)로 상대적 빈도를 표시")
            bulletPoint("가장 자주 하는 운동 순으로 정렬")
        }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "arrow.left.arrow.right", title: "균형 잡힌 구성")
            bulletPoint("밀기 / 당기기 / 하체 / 코어 균형을 권장합니다")
            bulletPoint("특정 운동에 편중되면 근육 불균형과 부상 위험이 증가합니다")
            bulletPoint("다양한 운동 패턴으로 전신 균형 발달을 추구하세요")
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.max.fill", title: "활용 팁")
            bulletPoint("소홀한 부위를 발견하고 보완하세요")
            bulletPoint("주기적으로 새로운 운동을 추가해 보세요")
            bulletPoint("상체/하체 비율을 주기적으로 확인하세요")
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
}
