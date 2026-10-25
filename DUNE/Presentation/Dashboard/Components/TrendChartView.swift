import SwiftUI
import Charts

struct TrendChartView: View {
    let scores: [ConditionScore]
    var lineColor: Color = .primary.opacity(0.82)
    var labelColor: Color = .primary.opacity(0.72)
    var referenceColor: Color = .primary.opacity(0.26)
    var compact = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 4) {
            if compact {
                chart
                    .frame(height: 48)
                    .clipped()
                compactLegend
                compactDates
            } else {
                chart
                HStack {
                    Text("Low")
                    Text("\(minimumScore)")
                    Spacer()
                    Text("Current")
                    Text("\(currentScore)")
                    Spacer()
                    Text("High")
                    Text("\(maximumScore)")
                }
                .font(.caption)
                .foregroundStyle(labelColor)
                HStack {
                    Text(firstDate)
                    Spacer()
                    Text(currentDate)
                }
                .font(.caption)
                .foregroundStyle(labelColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("dashboard-weekly-condition-chart")
        .accessibilityLabel("Condition Trend")
        .accessibilityValue(accessibilitySummary)
    }

    private var chart: some View {
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
    }

    private var compactLegend: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                compactLegendRows
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        captionPair("Low", value: minimumScore)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                        captionPair("Current", value: currentScore)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                        captionPair("High", value: maximumScore)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    compactLegendRows
                }
            }
        }
        .font(.caption)
        .foregroundStyle(labelColor)
    }

    private var compactLegendRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            captionPair("Low", value: minimumScore)
            captionPair("Current", value: currentScore)
            captionPair("High", value: maximumScore)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func captionPair(_ title: LocalizedStringKey, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text(value.formatted())
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var compactDates: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                compactDateRows
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        Text(firstDate)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 8)
                        Text(currentDate)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    compactDateRows
                }
            }
        }
        .font(.caption)
        .foregroundStyle(labelColor)
    }

    private var compactDateRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(firstDate)
            Text(currentDate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var minimumScore: Int { scores.map(\.score).min() ?? 0 }
    private var maximumScore: Int { scores.map(\.score).max() ?? 0 }
    private var currentScore: Int { scores.first?.score ?? 0 }
    private var firstDate: String { scores.last?.date.formatted(.dateTime.month(.abbreviated).day()) ?? "" }
    private var currentDate: String { scores.first?.date.formatted(.dateTime.month(.abbreviated).day()) ?? "" }

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
