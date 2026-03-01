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
}
