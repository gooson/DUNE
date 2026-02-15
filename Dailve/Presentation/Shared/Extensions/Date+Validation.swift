import Foundation

extension Date {
    /// Whether this date is in the future compared to now.
    /// Allows a 60-second tolerance to avoid false positives
    /// from DatePicker minute-level precision.
    var isFuture: Bool { self > Date().addingTimeInterval(60) }
}
