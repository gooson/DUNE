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
                Label("Workout Intensity", systemImage: "gauge.with.dots.needle.33percent")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if rpe != nil {
                    Button("Reset") { rpe = nil }
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
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
                    .foregroundStyle(DS.Color.textSecondary)
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
        case 1: String(localized: "Very Easy — Barely noticeable")
        case 2: String(localized: "Easy — Light movement")
        case 3: String(localized: "Slightly Easy — Comfortable exercise")
        case 4: String(localized: "Below Moderate — Slight effort")
        case 5: String(localized: "Moderate — Appropriate intensity")
        case 6: String(localized: "Above Moderate — Starting to get hard")
        case 7: String(localized: "Hard — Difficult to talk")
        case 8: String(localized: "Very Hard — Significant effort needed")
        case 9: String(localized: "Extremely Hard — Near limit")
        case 10: String(localized: "Maximum — Cannot continue")
        default: ""
        }
    }
}
