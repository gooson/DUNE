import Foundation

extension FatigueLevel {

    var displayName: String {
        switch self {
        case .noData:           String(localized: "No Data")
        case .fullyRecovered:   String(localized: "Fully Recovered")
        case .wellRested:       String(localized: "Well Rested")
        case .lightFatigue:     String(localized: "Light Fatigue")
        case .mildFatigue:      String(localized: "Mild Fatigue")
        case .moderateFatigue:  String(localized: "Moderate Fatigue")
        case .notableFatigue:   String(localized: "Notable Fatigue")
        case .highFatigue:      String(localized: "High Fatigue")
        case .veryHighFatigue:  String(localized: "Very High Fatigue")
        case .extremeFatigue:   String(localized: "Extreme Fatigue")
        case .overtrained:      String(localized: "Overtrained")
        }
    }
}
