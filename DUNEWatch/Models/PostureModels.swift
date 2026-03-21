import Foundation

// MARK: - Activity State

/// Activity state detected by CMMotionActivityManager.
enum PostureActivityState: String, Sendable {
    case stationary
    case walking
    case running
    case unknown
}

// MARK: - Gait Quality Score

/// Gait quality score computed from wrist motion during walking.
struct GaitQualityScore: Sendable, Equatable {
    /// Arm swing symmetry (0.0-1.0, higher = more symmetric).
    let symmetry: Double
    /// Step regularity (0.0-1.0, higher = more regular).
    let regularity: Double
    /// Overall score (0-100).
    let overall: Int

    static let zero = GaitQualityScore(symmetry: 0, regularity: 0, overall: 0)
}

