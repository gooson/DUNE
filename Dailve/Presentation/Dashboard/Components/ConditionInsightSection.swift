import SwiftUI

/// Shows contextual interpretation and activity guidance based on condition score status.
struct ConditionInsightSection: View {
    let status: ConditionScore.Status

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Today's Insight")
                .font(.subheadline)
                .fontWeight(.semibold)

            InlineCard {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    Text(status.emoji)
                        .font(.title2)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(interpretation)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(guidance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.label), \(interpretation), \(guidance)")
    }

    // MARK: - Content

    private var interpretation: String {
        switch status {
        case .excellent: "컨디션이 최상입니다"
        case .good:      "컨디션이 양호합니다"
        case .fair:      "평소 수준입니다"
        case .tired:     "피로가 누적되어 있습니다"
        case .warning:   "회복이 필요합니다"
        }
    }

    private var guidance: String {
        switch status {
        case .excellent:
            "고강도 운동이나 도전적인 목표를 시도하기 좋은 날입니다. 신체가 충분히 회복된 상태이므로 평소보다 더 적극적으로 활동해 보세요."
        case .good:
            "일상적인 운동을 유지하기 좋은 상태입니다. 균형 잡힌 활동으로 좋은 컨디션을 이어가세요."
        case .fair:
            "무리하지 않는 중간 강도의 활동을 추천합니다. 규칙적인 수면 패턴을 유지하면 컨디션 개선에 도움이 됩니다."
        case .tired:
            "가벼운 산책이나 스트레칭 위주의 활동을 권장합니다. 충분한 수면과 휴식으로 회복에 집중하세요."
        case .warning:
            "오늘은 휴식을 우선하세요. 저강도 활동만 하시고, 수면의 질을 높이는 데 집중하는 것이 좋습니다."
        }
    }
}
