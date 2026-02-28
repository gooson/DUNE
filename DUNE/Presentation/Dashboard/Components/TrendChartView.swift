import SwiftUI
import Charts

struct TrendChartView: View {
    let scores: [ConditionScore]

    @Environment(\.appTheme) private var theme

    var body: some View {
        Chart(scores.reversed(), id: \.date) { score in
            LineMark(
                x: .value("Date", score.date, unit: .day),
                y: .value("Score", score.score)
            )
            .foregroundStyle(theme.sandColor.opacity(0.5))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", score.date, unit: .day),
                y: .value("Score", score.score)
            )
            .foregroundStyle(score.status.color)
            .symbolSize(30)
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}
