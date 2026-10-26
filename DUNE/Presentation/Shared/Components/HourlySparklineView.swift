import SwiftUI
import Charts

/// Compact sparkline chart showing today's hourly score progression.
/// Used on hero cards alongside the score ring.
struct HourlySparklineView: View {
    let data: HourlySparklineData
    let tintColor: Color
    var height: CGFloat = 32
    var showsReferenceLabels = false
    var showsArea = true
    var showsTimeRange = false
    var usesTimelineAxis = false
    var anchorsTimelineToNow = false
    var accessibilityTitle: LocalizedStringKey = "Score Trend"

    var body: some View {
        if data.points.isEmpty {
            Rectangle()
                .fill(.clear)
                .frame(height: height)
        } else {
            VStack(spacing: 4) {
            Chart {
                ForEach(data.points) { point in
                LineMark(
                    x: .value("Hour", xValue(for: point)),
                    y: .value("Score", point.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(tintColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                if showsArea {
                    AreaMark(
                        x: .value("Hour", xValue(for: point)),
                        y: .value("Score", point.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(areaGradient)
                }
                }

                RuleMark(y: .value("Current", data.currentScore))
                    .foregroundStyle(tintColor.opacity(0.22))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: xDomain)
            .chartYScale(domain: computedYDomain)
            .frame(height: height)
            .clipped()
            if showsTimeRange, let first = data.points.first?.date, let last = data.points.last?.date {
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Text(first, format: .dateTime.month(.abbreviated).day().hour().minute())
                    Text("–")
                    Text(last, format: .dateTime.month(.abbreviated).day().hour().minute())
                }
                .font(.caption2)
                .foregroundStyle(tintColor.opacity(0.9))
            }
            if showsReferenceLabels {
                HStack {
                    Text("Low")
                    Text("\(minimumScore)")
                    Spacer()
                    Text("Current")
                    Text("\(Int(data.currentScore))")
                    Spacer()
                    Text("High")
                    Text("\(maximumScore)")
                }
                HStack {
                    Text(hourLabel(data.points.first?.hour ?? 0))
                    Spacer()
                    Text(hourLabel(data.points.last?.hour ?? 0))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityTitle)
            .accessibilityValue(accessibilitySummary)
        }
    }

    private var minimumScore: Int { Int(data.points.map(\.score).min() ?? 0) }
    private var maximumScore: Int { Int(data.points.map(\.score).max() ?? 0) }
    private func hourLabel(_ hour: Int) -> String { String(format: "%02d:00", hour) }

    private func xValue(for point: HourlySparklineData.HourlyPoint) -> Double {
        usesTimelineAxis ? point.date.timeIntervalSince1970 : Double(point.index)
    }

    private var xDomain: ClosedRange<Double> {
        guard usesTimelineAxis else { return 0...Double(max(data.points.count - 1, 1)) }
        let end = (anchorsTimelineToNow ? Date.now : data.points.last?.date ?? Date.now).timeIntervalSince1970
        let windowStart = end - TimePeriod.day.visibleDomainSeconds
        // Today labels the observed range; do not reserve leading space before
        // its first measurement when fewer than 24 hours are available.
        let start = anchorsTimelineToNow
            ? max(windowStart, data.points.first?.date.timeIntervalSince1970 ?? windowStart)
            : windowStart
        return min(start, end - 60)...end
    }

    private var accessibilitySummary: String {
        let first = data.points.first?.score ?? 0
        let last = data.points.last?.score ?? 0
        let firstTime = data.points.first?.date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
            ?? hourLabel(data.points.first?.hour ?? 0)
        let lastTime = data.points.last?.date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
            ?? hourLabel(data.points.last?.hour ?? 0)
        let direction = last > first + 2 ? String(localized: "Rising")
            : last < first - 2 ? String(localized: "Falling") : String(localized: "Stable")
        let format = String(localized: "From %@ to %@. Minimum %d, maximum %d, current %d.")
        let values = String(
            format: format,
            locale: .current,
            showsTimeRange ? firstTime : hourLabel(data.points.first?.hour ?? 0),
            showsTimeRange ? lastTime : hourLabel(data.points.last?.hour ?? 0),
            minimumScore,
            maximumScore,
            Int(data.currentScore)
        )
        return "\(direction). \(values)"
    }

    /// Hoisted gradient to avoid allocation inside Chart closure body.
    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [tintColor.opacity(0.3), tintColor.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Y-axis domain computed once per body evaluation.
    private var computedYDomain: ClosedRange<Double> {
        let scores = data.points.map(\.score)
        let minScore = (scores.min() ?? 0) - 5
        let maxScore = (scores.max() ?? 100) + 5
        return max(0, minScore)...min(100, maxScore)
    }
}
