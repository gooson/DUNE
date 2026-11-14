import SwiftUI

struct RestTimerView: View {
    @Bindable var timer: RestTimerViewModel

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("Rest Timer")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)

            Text(timer.formattedTime)
                .font(DS.Typography.cardScore)
                .foregroundStyle(theme.heroTextGradient)
                .monospacedDigit()
                .contentTransition(.numericText())

            ProgressView(value: timer.progress)
                .tint(DS.Color.activity)

            let actionsLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: DS.Spacing.sm))
                : AnyLayout(HStackLayout(spacing: DS.Spacing.lg))
            actionsLayout {
                Button {
                    timer.addTime(30)
                } label: {
                    Text("+30s")
                        .font(dynamicTypeSize.isAccessibilitySize ? .body.weight(.medium) : .caption.weight(.medium))
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: dynamicTypeSize.isAccessibilitySize ? 44 : nil)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button {
                    timer.stop()
                } label: {
                    Text("Skip")
                        .font(dynamicTypeSize.isAccessibilitySize ? .body.weight(.medium) : .caption.weight(.medium))
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: dynamicTypeSize.isAccessibilitySize ? 44 : nil)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DS.Color.onActivity)
                .tint(DS.Color.activity)
                .accessibilityIdentifier("rest-timer-skip")
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
    }
}
