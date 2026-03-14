import SwiftUI

/// Shared chart header for score detail views (visible range label + trend toggle).
/// Used by Condition, Training Readiness, and Wellness score detail views.
struct ScoreDetailChartHeader: View {
    let visibleRangeLabel: String
    @Binding var showTrendLine: Bool
    let tintColor: Color

    var body: some View {
        HStack {
            Text(visibleRangeLabel)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(DS.Color.textSecondary)
                .contentTransition(.numericText())
                .animation(DS.Animation.snappy, value: visibleRangeLabel)

            Spacer()

            Button {
                withAnimation(DS.Animation.snappy) {
                    showTrendLine.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                    Text("Trend")
                        .font(.caption)
                }
                .foregroundStyle(showTrendLine ? tintColor : .secondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    Capsule()
                        .fill(showTrendLine
                              ? tintColor.opacity(0.12)
                              : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: showTrendLine)
        }
    }
}
