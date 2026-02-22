import Foundation

enum Equipment: String, Codable, CaseIterable, Sendable {
    // Free Weights
    case barbell
    case dumbbell
    case kettlebell
    case ezBar
    case trapBar

    // Machines (specific)
    case smithMachine
    case legPressMachine
    case hackSquatMachine
    case chestPressMachine
    case shoulderPressMachine
    case latPulldownMachine
    case legExtensionMachine
    case legCurlMachine
    case pecDeckMachine
    case cableMachine

    // Generic (backward compat)
    case machine
    case cable

    // Bodyweight & Accessories
    case bodyweight
    case pullUpBar
    case dipStation

    // Small Equipment
    case band
    case trx
    case medicineBall
    case stabilityBall

    // Other
    case other
}

extension Equipment {
    /// Fallback mapping while exercises.json still uses legacy generic equipment values.
    /// Example: selecting `legPressMachine` should still surface entries tagged as `.machine`.
    var compatibleLibraryValues: Set<Equipment> {
        switch self {
        case .smithMachine,
             .legPressMachine,
             .hackSquatMachine,
             .chestPressMachine,
             .shoulderPressMachine,
             .latPulldownMachine,
             .legExtensionMachine,
             .legCurlMachine,
             .pecDeckMachine:
            return [self, .machine]

        case .cableMachine:
            return [self, .cable]

        default:
            return [self]
        }
    }
}
