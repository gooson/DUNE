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
            InfoSheetHelpers.SectionHeader(icon: "lightbulb.fill", title: "개요")
            Text("각 운동별 역대 최고 무게를 추적합니다. 꾸준한 진전을 확인하고 점진적 과부하(Progressive Overload) 원칙을 적용하는 데 활용하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "scalemass.fill", title: "측정 방식")
            InfoSheetHelpers.BulletPoint(text: "세션 내 세트 평균 무게를 기준으로 측정")
            InfoSheetHelpers.BulletPoint(text: "운동별로 역대 최고 기록만 표시")
            InfoSheetHelpers.BulletPoint(text: "0~500kg 범위 내 유효 기록만 반영")
        }
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "sparkles", title: "NEW 배지")
            InfoSheetHelpers.BulletPoint(text: "최근 7일 이내 갱신된 기록에 표시")
            InfoSheetHelpers.BulletPoint(text: "꾸준한 진전을 시각적으로 확인 가능")
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "lightbulb.max.fill", title: "활용 팁")
            InfoSheetHelpers.BulletPoint(text: "점진적 과부하 추적에 활용하세요")
            InfoSheetHelpers.BulletPoint(text: "장기적으로 강해지는 과정을 기록으로 확인하세요")
            InfoSheetHelpers.BulletPoint(text: "무리한 중량 증가보다 일관된 진전이 중요합니다")
        }
    }
}
