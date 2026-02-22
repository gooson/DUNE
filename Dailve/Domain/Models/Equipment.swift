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
