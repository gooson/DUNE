import SwiftUI

/// RPE (Rate of Perceived Exertion) input view with emoji scale.
/// 1-10 scale, optional (user can skip).
struct RPEInputView: View {
    @Binding var rpe: Int?

    private let levels: [(emoji: String, label: String)] = [
        ("😴", "1"), ("😌", "2"), ("🙂", "3"), ("😐", "4"), ("😊", "5"),
        ("💪", "6"), ("😤", "7"), ("🥵", "8"), ("🔥", "9"), ("💀", "10"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Label("운동 강도", systemImage: "gauge.with.dots.needle.33percent")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if rpe != nil {
                    Button("초기화") { rpe = nil }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(1...10, id: \.self) { value in
                        rpeButton(value: value)
                    }
                }
                .padding(.horizontal, DS.Spacing.xxs)
            }

            if let selected = rpe {
                Text(rpeDescription(selected))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
    }

    private func rpeButton(value: Int) -> some View {
        let isSelected = rpe == value
        let level = levels[value - 1]

        return Button {
            withAnimation(DS.Animation.snappy) {
                rpe = isSelected ? nil : value
            }
        } label: {
            VStack(spacing: DS.Spacing.xxs) {
                Text(level.emoji)
                    .font(.title3)
                Text(level.label)
                    .font(.caption2.weight(.medium).monospacedDigit())
            }
            .frame(width: 36, height: 52)
            .background(
                isSelected ? rpeColor(value).opacity(0.2) : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(
                        isSelected ? rpeColor(value) : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func rpeColor(_ value: Int) -> Color {
        switch value {
        case 1...3: DS.Color.positive
        case 4...6: DS.Color.caution
        case 7...8: .orange
        case 9...10: DS.Color.negative
        default: .gray
        }
    }

    private func rpeDescription(_ value: Int) -> String {
        switch value {
        case 1: "매우 쉬움 — 거의 느끼지 못함"
        case 2: "쉬움 — 가벼운 움직임"
        case 3: "약간 쉬움 — 편안한 운동"
        case 4: "보통 이하 — 약간의 노력"
        case 5: "보통 — 적당한 강도"
        case 6: "보통 이상 — 약간 힘들기 시작"
        case 7: "힘듦 — 대화하기 어려움"
        case 8: "매우 힘듦 — 상당한 노력 필요"
        case 9: "극도로 힘듦 — 거의 한계"
        case 10: "최대 — 더 이상 불가"
        default: ""
        }
    }
}
