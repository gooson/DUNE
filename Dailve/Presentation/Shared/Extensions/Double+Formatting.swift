import Foundation

extension Double {
    /// Formats a number with thousand separators.
    /// - Parameter fractionDigits: Number of decimal places (default 0).
    /// - Returns: Formatted string with comma separators, e.g. "1,234" or "1,234.5".
    func formattedWithSeparator(fractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Int {
    /// Formats an integer with thousand separators.
    /// - Returns: Formatted string with comma separators, e.g. "1,234".
    var formattedWithSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
