import SwiftUI

// MARK: - Zone Display (Watch)

extension HeartRateZone.Zone {
    /// Localized zone name for Watch UI display.
    var displayName: String {
        switch self {
        case .zone1: String(localized: "Recovery")
        case .zone2: String(localized: "Fat Burn")
        case .zone3: String(localized: "Cardio")
        case .zone4: String(localized: "Hard")
        case .zone5: String(localized: "Peak")
        }
    }

    /// DS color token for this zone.
    var color: Color {
        switch self {
        case .zone1: DS.Color.zone1
        case .zone2: DS.Color.zone2
        case .zone3: DS.Color.zone3
        case .zone4: DS.Color.zone4
        case .zone5: DS.Color.zone5
        }
    }
}
