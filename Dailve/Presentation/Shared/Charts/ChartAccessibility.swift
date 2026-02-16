import SwiftUI
import Charts

// MARK: - Shared Helpers

private func emptyChartDescriptor(title: String, yAxisTitle: String = "Value") -> AXChartDescriptor {
    AXChartDescriptor(
        title: title,
        summary: "No data available",
        xAxis: AXNumericDataAxisDescriptor(title: "Date", range: 0...1, gridlinePositions: []) { _ in "" },
        yAxis: AXNumericDataAxisDescriptor(title: yAxisTitle, range: 0...1, gridlinePositions: []) { _ in "" },
        series: []
    )
}

private func makeDateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("MMMdE")
    return formatter
}

private func dateRange<T>(from sorted: [T], dateKeyPath: KeyPath<T, Date>) -> (min: Double, max: Double) {
    let first = sorted.first?[keyPath: dateKeyPath].timeIntervalSince1970 ?? 0
    let last = sorted.last?[keyPath: dateKeyPath].timeIntervalSince1970 ?? 1
    return (first, last)
}

// MARK: - Standard Chart Descriptor (line/bar/area)

/// Provides AXChartDescriptor for VoiceOver navigation of standard single-value charts.
struct StandardChartAccessibility: AXChartDescriptorRepresentable {
    let title: String
    let data: [ChartDataPoint]
    let unitSuffix: String
    let valueFormat: String

    init(title: String, data: [ChartDataPoint], unitSuffix: String, valueFormat: String = "%.1f") {
        self.title = title
        self.data = data
        self.unitSuffix = unitSuffix
        self.valueFormat = valueFormat
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        guard !data.isEmpty else {
            return emptyChartDescriptor(title: title)
        }

        let sorted = data.sorted { $0.date < $1.date }
        let range = dateRange(from: sorted, dateKeyPath: \.date)

        let values = sorted.map(\.value)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1

        let dateFormatter = makeDateFormatter()

        let xAxis = AXNumericDataAxisDescriptor(
            title: "Date",
            range: range.min...range.max,
            gridlinePositions: []
        ) { value in
            dateFormatter.string(from: Date(timeIntervalSince1970: value))
        }

        let yAxis = AXNumericDataAxisDescriptor(
            title: unitSuffix,
            range: minVal...maxVal,
            gridlinePositions: []
        ) { value in
            "\(String(format: valueFormat, value)) \(unitSuffix)"
        }

        let dataPoints = sorted.map { point in
            AXDataPoint(
                x: point.date.timeIntervalSince1970,
                y: point.value,
                label: "\(dateFormatter.string(from: point.date)): \(String(format: valueFormat, point.value)) \(unitSuffix)"
            )
        }

        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: true,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: title,
            summary: "\(sorted.count) data points",
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }
}

// MARK: - Range Chart Descriptor (RHR min-max)

/// Provides AXChartDescriptor for VoiceOver navigation of range bar charts (min-max-avg).
struct RangeChartAccessibility: AXChartDescriptorRepresentable {
    let title: String
    let data: [RangeDataPoint]
    let unitSuffix: String

    func makeChartDescriptor() -> AXChartDescriptor {
        guard !data.isEmpty else {
            return emptyChartDescriptor(title: title)
        }

        let sorted = data.sorted { $0.date < $1.date }
        let range = dateRange(from: sorted, dateKeyPath: \.date)

        let allMin = sorted.map(\.min).min() ?? 0
        let allMax = sorted.map(\.max).max() ?? 1

        let dateFormatter = makeDateFormatter()

        let xAxis = AXNumericDataAxisDescriptor(
            title: "Date",
            range: range.min...range.max,
            gridlinePositions: []
        ) { value in
            dateFormatter.string(from: Date(timeIntervalSince1970: value))
        }

        let yAxis = AXNumericDataAxisDescriptor(
            title: unitSuffix,
            range: allMin...allMax,
            gridlinePositions: []
        ) { value in
            "\(String(format: "%.0f", value)) \(unitSuffix)"
        }

        let dataPoints = sorted.map { point in
            AXDataPoint(
                x: point.date.timeIntervalSince1970,
                y: point.average,
                label: "\(dateFormatter.string(from: point.date)): \(Int(point.min))–\(Int(point.max)) \(unitSuffix), avg \(Int(point.average))"
            )
        }

        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: false,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: title,
            summary: "\(sorted.count) data points",
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }
}

// MARK: - Sleep Chart Descriptor (stacked)

/// Provides AXChartDescriptor for VoiceOver navigation of sleep stacked bar charts.
struct SleepChartAccessibility: AXChartDescriptorRepresentable {
    let title: String
    let data: [StackedDataPoint]

    func makeChartDescriptor() -> AXChartDescriptor {
        guard !data.isEmpty else {
            return emptyChartDescriptor(title: title, yAxisTitle: "Hours")
        }

        let sorted = data.sorted { $0.date < $1.date }
        let range = dateRange(from: sorted, dateKeyPath: \.date)

        let maxHours = (sorted.map(\.total).max() ?? 1) / 3600

        let dateFormatter = makeDateFormatter()

        let xAxis = AXNumericDataAxisDescriptor(
            title: "Date",
            range: range.min...range.max,
            gridlinePositions: []
        ) { value in
            dateFormatter.string(from: Date(timeIntervalSince1970: value))
        }

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Hours",
            range: 0...maxHours,
            gridlinePositions: []
        ) { value in
            "\(String(format: "%.1f", value)) hours"
        }

        let dataPoints = sorted.map { point in
            let totalHours = point.total / 3600
            let breakdown = point.segments.map { "\($0.category): \(String(format: "%.1f", $0.value / 3600))h" }.joined(separator: ", ")
            return AXDataPoint(
                x: point.date.timeIntervalSince1970,
                y: totalHours,
                label: "\(dateFormatter.string(from: point.date)): \(String(format: "%.1f", totalHours)) hours (\(breakdown))"
            )
        }

        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: false,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: title,
            summary: "\(sorted.count) nights",
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }
}
