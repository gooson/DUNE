import SwiftUI

/// Expandable section explaining how the condition score is calculated.
struct ConditionExplainerSection: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Custom header (replaces DisclosureGroup for chevron direction control)
            Button {
                withAnimation(DS.Animation.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("점수 계산 원리")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(DS.Animation.snappy, value: isExpanded)
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isExpanded)

            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    explainerItem(
                        icon: "waveform.path.ecg",
                        title: "HRV (심박변이도)",
                        description: "심박 사이 간격의 변동을 측정합니다. HRV가 높을수록 자율신경계가 유연하게 반응하고 있어 좋은 회복 상태를 의미합니다."
                    )

                    explainerItem(
                        icon: "calendar",
                        title: "개인 기준선",
                        description: "최근 7일간의 HRV 데이터로 나만의 기준선을 설정합니다. 절대 수치가 아닌 개인 변화 추이를 기반으로 분석합니다."
                    )

                    explainerItem(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "점수 산출",
                        description: "오늘의 HRV가 기준선 대비 어디에 위치하는지를 통계적으로 계산하여 0~100점으로 변환합니다."
                    )

                    explainerItem(
                        icon: "heart.fill",
                        title: "RHR 보정",
                        description: "안정시 심박수(RHR)의 변화를 추가로 반영합니다. HRV가 낮아지면서 RHR이 높아지면 피로 신호를 더 강하게 감지합니다."
                    )
                }
                .padding(.top, DS.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func explainerItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(DS.Color.hrv)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
