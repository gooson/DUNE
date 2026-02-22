import Foundation

private enum WatchFormatterCache {
    static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

extension Int {
    var formattedWithSeparator: String {
        WatchFormatterCache.integerFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
