import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Sendable, Identifiable {
    var id: String { rawValue }

    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case quadriceps
    case hamstrings
    case glutes
    case calves
    case core
    case forearms
    case traps
    case lats

    /// Estimated full recovery time in hours, differentiated by muscle group size.
    var recoveryHours: Double {
        switch self {
        case .quadriceps, .hamstrings, .glutes, .back, .lats:
            return 72  // Large muscles: 3 days
        case .chest, .shoulders, .traps:
            return 48  // Medium muscles: 2 days
        case .biceps, .triceps, .forearms, .core, .calves:
            return 36  // Small muscles: 1.5 days
        }
    }
}
