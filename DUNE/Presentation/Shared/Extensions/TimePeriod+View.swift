import Foundation

/// Presentation-layer formatting for TimePeriod.
/// Separates locale-specific date formatting from the Domain model.
extension TimePeriod {

    /// Formatted label for the given offset's date range.
    func rangeLabel(offset: Int) -> String {
        let range = dateRange(offset: offset)
        let formatter = DateFormatter()
        switch self {
        case .day:
            formatter.setLocalizedDateFormatFromTemplate("MdE")
            return formatter.string(from: range.start)
        case .week:
            formatter.setLocalizedDateFormatFromTemplate("Md")
            let start = formatter.string(from: range.start)
            let end = formatter.string(from: range.end)
            return "\(start) – \(end)"
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("yM")
            return formatter.string(from: range.start)
        case .sixMonths:
            formatter.setLocalizedDateFormatFromTemplate("yM")
            let start = formatter.string(from: range.start)
            let end = formatter.string(from: range.end)
            return "\(start) – \(end)"
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("y")
            return formatter.string(from: range.start)
        }
    }

    /// Formatted label for the visible date range starting at `scrollDate`.
    func visibleRangeLabel(from scrollDate: Date) -> String {
        let calendar = Calendar.current
        let end: Date
        switch self {
        case .day:
            end = calendar.date(byAdding: .hour, value: 24, to: scrollDate) ?? scrollDate
        case .week:
            end = calendar.date(byAdding: .day, value: 7, to: scrollDate) ?? scrollDate
        case .month:
            end = calendar.date(byAdding: .month, value: 1, to: scrollDate) ?? scrollDate
        case .sixMonths:
            end = calendar.date(byAdding: .month, value: 6, to: scrollDate) ?? scrollDate
        case .year:
            end = calendar.date(byAdding: .year, value: 1, to: scrollDate) ?? scrollDate
        }

        let formatter = DateFormatter()
        switch self {
        case .day:
            formatter.setLocalizedDateFormatFromTemplate("MMMdE")
            return formatter.string(from: scrollDate)
        case .week:
            formatter.setLocalizedDateFormatFromTemplate("Md")
            return "\(formatter.string(from: scrollDate)) – \(formatter.string(from: end))"
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            return formatter.string(from: scrollDate)
        case .sixMonths:
            formatter.setLocalizedDateFormatFromTemplate("yM")
            return "\(formatter.string(from: scrollDate)) – \(formatter.string(from: end))"
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("y")
            return formatter.string(from: scrollDate)
        }
    }
}
