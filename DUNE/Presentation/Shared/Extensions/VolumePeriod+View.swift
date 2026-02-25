import Foundation

extension VolumePeriod {
    var displayName: String {
        switch self {
        case .week: "1W"
        case .month: "1M"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        }
    }
}
