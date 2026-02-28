import SwiftUI

extension InjuryRecord {
    private enum DateCache {
        static let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "M/d"
            return f
        }()
    }

    var durationLabel: String {
        let days = durationDays
        if isActive {
            return days == 0 ? "Today" : "\(days)d"
        } else {
            return "\(days)d"
        }
    }

    var dateRangeLabel: String {
        let start = DateCache.formatter.string(from: startDate)
        if isActive {
            return "\(start)~"
        } else {
            let end = endDate.map { DateCache.formatter.string(from: $0) } ?? ""
            return "\(start) ~ \(end)"
        }
    }
}
