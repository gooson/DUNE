import SwiftUI

/// Explains how personal records are tracked and calculated.
struct PersonalRecordsInfoSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                overviewSection
                measurementSection
                healthKitSection
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
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Spacer()
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "lightbulb.fill", title: "개요")
            Text("근력과 유산소 기록을 함께 분석해 개인 최고치를 추적합니다. 운동의 진행 상황을 한 화면에서 확인하고, 훈련 방향을 조정하는 데 활용하세요.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "scalemass.fill", title: "측정 방식")
            InfoSheetHelpers.BulletPoint(text: "근력 PR: 세션 내 세트 평균 무게 기준")
            InfoSheetHelpers.BulletPoint(text: "유산소 PR: 페이스/거리/시간/칼로리/고도 기준")
            InfoSheetHelpers.BulletPoint(text: "유산소는 HealthKit 데이터를 우선 사용하고, 필요 시 수동 기록으로 보완")
            InfoSheetHelpers.BulletPoint(text: "비정상 값은 자동 제외 (예: 0 또는 범위 초과 값)")
        }
    }

    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InfoSheetHelpers.SectionHeader(icon: "apple.logo", title: "HealthKit 연동")
            InfoSheetHelpers.BulletPoint(text: "가능한 경우 심박, 걸음수, 날씨, 실내/실외 정보를 함께 표시")
            InfoSheetHelpers.BulletPoint(text: "권한이 없거나 데이터가 없으면 해당 카드가 숨겨지고 안내 문구가 표시")
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
            InfoSheetHelpers.BulletPoint(text: "근력은 중량 추세, 유산소는 페이스/거리 추세를 함께 보세요")
            InfoSheetHelpers.BulletPoint(text: "NEW 배지를 기준으로 최근 성과를 빠르게 확인할 수 있습니다")
            InfoSheetHelpers.BulletPoint(text: "무리한 강도 상승보다 일관된 반복이 장기 성과에 유리합니다")
        }
    }
}
