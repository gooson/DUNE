import Foundation

extension VolumePeriod {
    var displayName: String {
        switch self {
        case .week: String(localized: "1W")
        case .month: String(localized: "1M")
        case .threeMonths: String(localized: "3M")
        case .sixMonths: String(localized: "6M")
        }
    }

    var visibleDomainSeconds: TimeInterval {
        TimeInterval(days) * 86_400
    }

    var chartAxisStrideCount: Int {
        switch self {
        case .week: 1
        case .month: 7
        case .threeMonths: 14
        case .sixMonths: 30
        }
    }

    func initialVisibleStart(latestDate: Date) -> Date {
        let calendar = Calendar.current
        let latestDay = calendar.startOfDay(for: latestDate)
        return calendar.date(byAdding: .day, value: -(days - 1), to: latestDay) ?? latestDay
    }

    func visibleRangeLabel(from scrollDate: Date) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: scrollDate)
        let end = calendar.date(byAdding: .day, value: days - 1, to: start) ?? start
        let formatter = DateFormatter()

        switch self {
        case .week, .month:
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
        case .threeMonths, .sixMonths:
            formatter.setLocalizedDateFormatFromTemplate("yMMM")
        }

        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}
