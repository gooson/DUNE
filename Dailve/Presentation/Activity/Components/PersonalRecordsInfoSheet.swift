import SwiftUI

/// Explains how personal records are tracked and calculated.
struct PersonalRecordsInfoSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                overviewSection
                measurementSection
                badgeSection
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
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("개인 기록 (PR)")
                    .font(.headline)
                Text("Personal Records")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.fill", title: "개요")
            Text("각 운동별 역대 최고 무게를 추적합니다. 꾸준한 진전을 확인하고 점진적 과부하(Progressive Overload) 원칙을 적용하는 데 활용하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "scalemass.fill", title: "측정 방식")
            bulletPoint("세션 내 세트 평균 무게를 기준으로 측정")
            bulletPoint("운동별로 역대 최고 기록만 표시")
            bulletPoint("0~500kg 범위 내 유효 기록만 반영")
        }
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "sparkles", title: "NEW 배지")
            bulletPoint("최근 7일 이내 갱신된 기록에 표시")
            bulletPoint("꾸준한 진전을 시각적으로 확인 가능")
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.max.fill", title: "활용 팁")
            bulletPoint("점진적 과부하 추적에 활용하세요")
            bulletPoint("장기적으로 강해지는 과정을 기록으로 확인하세요")
            bulletPoint("무리한 중량 증가보다 일관된 진전이 중요합니다")
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
