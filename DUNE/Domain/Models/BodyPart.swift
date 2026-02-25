import Foundation

/// Body part for injury tracking — includes joints and muscle regions.
/// Maps to `MuscleGroup` via `affectedMuscleGroups` for Train tab integration.
enum BodyPart: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    var id: String { rawValue }

    // Joints
    case neck
    case shoulder
    case elbow
    case wrist
    case lowerBack
    case hip
    case knee
    case ankle

    // Muscle regions (maps 1:1 or 1:N to MuscleGroup)
    case chest
    case upperBack
    case biceps
    case triceps
    case forearms
    case core
    case quadriceps
    case hamstrings
    case glutes
    case calves

    /// Muscle groups affected when this body part is injured.
    var affectedMuscleGroups: [MuscleGroup] {
        switch self {
        case .neck:       return [.traps]
        case .shoulder:   return [.shoulders, .chest, .traps]
        case .elbow:      return [.biceps, .triceps, .forearms]
        case .wrist:      return [.forearms]
        case .lowerBack:  return [.back, .core]
        case .hip:        return [.glutes, .hamstrings, .quadriceps]
        case .knee:       return [.quadriceps, .hamstrings, .calves]
        case .ankle:      return [.calves]
        case .chest:      return [.chest]
        case .upperBack:  return [.back, .lats, .traps]
        case .biceps:     return [.biceps]
        case .triceps:    return [.triceps]
        case .forearms:   return [.forearms]
        case .core:       return [.core]
        case .quadriceps: return [.quadriceps]
        case .hamstrings: return [.hamstrings]
        case .glutes:     return [.glutes]
        case .calves:     return [.calves]
        }
    }

    /// Whether this body part has left/right distinction.
    var isLateral: Bool {
        switch self {
        case .shoulder, .elbow, .wrist, .hip, .knee, .ankle,
             .biceps, .triceps, .forearms, .quadriceps, .hamstrings, .glutes, .calves:
            return true
        case .neck, .lowerBack, .chest, .upperBack, .core:
            return false
        }
    }

    /// Whether this is a joint (vs muscle region).
    var isJoint: Bool {
        switch self {
        case .neck, .shoulder, .elbow, .wrist, .lowerBack, .hip, .knee, .ankle:
            return true
        default:
            return false
        }
    }
}

/// Left/right distinction for lateral body parts.
enum BodySide: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    var id: String { rawValue }

    case left
    case right
    case both
}
