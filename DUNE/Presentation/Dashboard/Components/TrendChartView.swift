import SwiftUI
import Charts

struct TrendChartView: View {
    let scores: [ConditionScore]
    var lineColor: Color = .primary.opacity(0.82)
    var labelColor: Color = .primary.opacity(0.72)
    var referenceColor: Color = .primary.opacity(0.26)

    var body: some View {
        VStack(spacing: 4) {
        Chart {
            ForEach(scores.reversed(), id: \.date) { score in
            LineMark(
                x: .value("Date", score.date, unit: .day),
                y: .value("Score", score.score)
            )
            .foregroundStyle(lineColor)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", score.date, unit: .day),
                y: .value("Score", score.score)
            )
            .foregroundStyle(score.status.color)
            .symbolSize(30)
            }

            RuleMark(y: .value("Current", scores.first?.score ?? 0))
                .foregroundStyle(referenceColor)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        HStack {
            Text("Low")
            Text("\(scores.map(\.score).min() ?? 0)")
            Spacer()
            Text("Current")
            Text("\(scores.first?.score ?? 0)")
            Spacer()
            Text("High")
            Text("\(scores.map(\.score).max() ?? 0)")
        }
        .font(.caption)
        .foregroundStyle(labelColor)
        HStack {
            Text(scores.last?.date.formatted(.dateTime.month(.abbreviated).day()) ?? "")
            Spacer()
            Text(scores.first?.date.formatted(.dateTime.month(.abbreviated).day()) ?? "")
        }
        .font(.caption)
        .foregroundStyle(labelColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("dashboard-weekly-condition-chart")
        .accessibilityLabel("Condition Trend")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let first = scores.last, let current = scores.first else { return "" }
        let direction = current.score > first.score + 2 ? String(localized: "Rising")
            : current.score < first.score - 2 ? String(localized: "Falling") : String(localized: "Stable")
        let format = String(localized: "From %@ to %@. Minimum %d, maximum %d, current %d.")
        let values = String(
            format: format,
            locale: .current,
            first.date.formatted(.dateTime.month(.abbreviated).day()),
            current.date.formatted(.dateTime.month(.abbreviated).day()),
            scores.map(\.score).min() ?? 0,
            scores.map(\.score).max() ?? 0,
            current.score
        )
        return "\(direction). \(values)"
    }
}
