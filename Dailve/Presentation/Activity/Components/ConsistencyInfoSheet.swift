import SwiftUI

/// Explains how workout consistency (streak) is calculated.
struct ConsistencyInfoSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                overviewSection
                currentStreakSection
                bestStreakSection
                monthlySection
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
            Image(systemName: "flame.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("운동 일관성")
                    .font(.headline)
                Text("Workout Consistency")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.fill", title: "개요")
            Text("얼마나 꾸준히 운동하는지를 추적합니다. 연속 운동일(Streak)과 월간 진행률을 통해 일관성을 확인하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var currentStreakSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "flame", title: "현재 Streak")
            bulletPoint("오늘 또는 어제를 포함한 연속 운동일 수")
            bulletPoint("20분 이상 운동한 날만 카운트")
            bulletPoint("하루라도 빠지면 Streak이 리셋됩니다")
        }
    }

    private var bestStreakSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "star.fill", title: "최고 Streak")
            bulletPoint("역대 가장 긴 연속 운동 기록")
            bulletPoint("현재 Streak이 최고 기록보다 길면 자동 갱신")
        }
    }

    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "calendar", title: "월간 진행률")
            bulletPoint("이번 달 운동 횟수를 목표와 비교")
            bulletPoint("기본 목표: 월 16회 (주 4회 기준)")
            bulletPoint("진행 바로 달성률을 시각화")
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.max.fill", title: "활용 팁")
            bulletPoint("강도보다 일관성이 장기 성과의 핵심입니다")
            bulletPoint("주 3~5회를 꾸준히 유지하는 것을 목표로 하세요")
            bulletPoint("휴식일도 회복에 중요하므로 매일 운동할 필요는 없습니다")
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
