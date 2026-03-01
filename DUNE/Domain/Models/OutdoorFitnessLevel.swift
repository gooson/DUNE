import Foundation

/// Categorization of outdoor exercise suitability based on weather score.
enum OutdoorFitnessLevel: Sendable, Hashable {
    case great    // 80-100
    case okay     // 60-79
    case caution  // 40-59
    case indoor   // 0-39

    init(score: Int) {
        switch score {
        case 80...100: self = .great
        case 60...79:  self = .okay
        case 40...59:  self = .caution
        default:       self = .indoor
        }
    }

    var displayName: String {
        switch self {
        case .great:   String(localized: "Great for outdoor exercise")
        case .okay:    String(localized: "Okay for outdoors")
        case .caution: String(localized: "Use caution outdoors")
        case .indoor:  String(localized: "Stay indoors")
        }
    }

    var shortDisplayName: String {
        switch self {
        case .great:   String(localized: "Great outdoors")
        case .okay:    String(localized: "Okay outdoors")
        case .caution: String(localized: "Caution")
        case .indoor:  String(localized: "Indoors")
        }
    }

    var systemImage: String {
        switch self {
        case .great:   "figure.run"
        case .okay:    "figure.walk"
        case .caution: "exclamationmark.triangle"
        case .indoor:  "house"
        }
    }
}
