import SwiftUI

struct RestTimerView: View {
    @Bindable var timer: RestTimerViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("Rest Timer")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(timer.formattedTime)
                .font(DS.Typography.cardScore)
                .monospacedDigit()
                .contentTransition(.numericText())

            ProgressView(value: timer.progress)
                .tint(DS.Color.activity)

            HStack(spacing: DS.Spacing.lg) {
                Button {
                    timer.addTime(30)
                } label: {
                    Text("+30s")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button {
                    timer.stop()
                } label: {
                    Text("Skip")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.activity)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
    }
}
