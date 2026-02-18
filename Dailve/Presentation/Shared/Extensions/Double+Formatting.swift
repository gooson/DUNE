import Foundation

private enum FormatterCache {
    static let integerFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()

    static let oneDecimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()
}

extension Double {
    /// Formats a number with thousand separators.
    /// - Parameter fractionDigits: Number of decimal places (default 0).
    /// - Returns: Formatted string with comma separators, e.g. "1,234" or "1,234.5".
    func formattedWithSeparator(fractionDigits: Int = 0) -> String {
        let formatter: NumberFormatter
        switch fractionDigits {
        case 0: formatter = FormatterCache.integerFormatter
        case 1: formatter = FormatterCache.oneDecimalFormatter
        default:
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = ","
            f.minimumFractionDigits = fractionDigits
            f.maximumFractionDigits = fractionDigits
            formatter = f
        }
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Int {
    /// Formats an integer with thousand separators.
    /// - Returns: Formatted string with comma separators, e.g. "1,234".
    var formattedWithSeparator: String {
        FormatterCache.integerFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
