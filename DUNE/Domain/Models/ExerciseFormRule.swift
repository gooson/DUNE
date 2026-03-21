import Foundation

// MARK: - Exercise Phase

/// Phases of a repetition cycle for strength exercises.
enum ExercisePhase: String, Sendable, CaseIterable {
    case setup      // Standing/starting position
    case descent    // Eccentric phase (lowering)
    case bottom     // Bottom/deepest position
    case ascent     // Concentric phase (raising)
    case lockout    // Top/completed position
}

// MARK: - Form Checkpoint

/// A single form checkpoint evaluated during a specific exercise phase.
struct FormCheckpoint: Sendable, Identifiable {
    var id: String { name }

    /// Human-readable name for display (e.g. "Knee Depth", "Back Angle").
    let name: String

    /// Keypoint names forming the angle triplet: (a, vertex, c).
    let jointA: String
    let jointVertex: String
    let jointC: String

    /// Angle range (degrees) for each status.
    let passRange: ClosedRange<Double>
    let cautionRange: ClosedRange<Double>
    // Anything outside caution = fail

    /// Which phases this checkpoint is active in.
    let activePhases: Set<ExercisePhase>

    /// Whether this is the primary angle used for phase detection.
    let isPrimaryAngle: Bool

    /// Short coaching cue spoken when the checkpoint is caution/warning.
    var coachingCue: String = ""

    /// Short positive cue spoken when the checkpoint is normal (good form).
    var positiveCue: String = ""

    func evaluate(degrees: Double) -> PostureStatus {
        guard degrees.isFinite else { return .unmeasurable }
        if passRange.contains(degrees) { return .normal }
        if cautionRange.contains(degrees) { return .caution }
        return .warning
    }
}

// MARK: - Exercise Form Rule

/// Complete form rule definition for a specific exercise.
struct ExerciseFormRule: Sendable, Identifiable {
    var id: String { exerciseID }

    let exerciseID: String
    let displayName: String
    let checkpoints: [FormCheckpoint]

    /// Recommended camera position for this exercise.
    let recommendedCameraPosition: CameraViewSide

    /// Phase transition thresholds for the primary angle.
    let descentThreshold: Double   // Below this = descent started
    let bottomThreshold: Double    // Below this = bottom reached
    let lockoutThreshold: Double   // Above this = lockout reached

    enum CameraViewSide: String, Sendable {
        case side   // Sagittal view (squat, deadlift)
        case front  // Frontal view (overhead press)
    }
}

// MARK: - Built-in Rules

extension ExerciseFormRule {

    /// Barbell Back Squat — side view recommended.
    static let barbellSquat = ExerciseFormRule(
        exerciseID: "barbell-squat",
        displayName: "Barbell Squat",
        checkpoints: [
            FormCheckpoint(
                name: "Knee Depth",
                jointA: "leftHip", jointVertex: "leftKnee", jointC: "leftAnkle",
                passRange: 60...100,     // Parallel or below
                cautionRange: 100...120, // Slightly above parallel
                activePhases: [.descent, .bottom],
                isPrimaryAngle: true,
                coachingCue: "Go deeper",
                positiveCue: "Good depth"
            ),
            FormCheckpoint(
                name: "Back Angle",
                jointA: "leftShoulder", jointVertex: "leftHip", jointC: "leftKnee",
                passRange: 40...70,      // Moderate torso lean
                cautionRange: 30...80,   // Slightly too upright or too forward
                activePhases: [.descent, .bottom, .ascent],
                isPrimaryAngle: false,
                coachingCue: "Keep your back straight",
                positiveCue: "Good back position"
            ),
        ],
        recommendedCameraPosition: .side,
        descentThreshold: 160,  // Knee angle drops below 160° → descent started
        bottomThreshold: 110,   // Knee angle drops below 110° → bottom reached
        lockoutThreshold: 165   // Knee angle rises above 165° → lockout
    )

    /// Conventional Deadlift — side view recommended.
    static let conventionalDeadlift = ExerciseFormRule(
        exerciseID: "conventional-deadlift",
        displayName: "Conventional Deadlift",
        checkpoints: [
            FormCheckpoint(
                name: "Hip Hinge",
                jointA: "leftShoulder", jointVertex: "leftHip", jointC: "leftKnee",
                passRange: 30...70,      // Proper hip hinge angle
                cautionRange: 20...80,
                activePhases: [.descent, .bottom, .ascent],
                isPrimaryAngle: false,
                coachingCue: "Hinge at your hips",
                positiveCue: "Good hip hinge"
            ),
            FormCheckpoint(
                name: "Knee Bend",
                jointA: "leftHip", jointVertex: "leftKnee", jointC: "leftAnkle",
                passRange: 130...170,    // Slight knee bend
                cautionRange: 110...175,
                activePhases: [.descent, .bottom],
                isPrimaryAngle: true,
                coachingCue: "Bend your knees slightly",
                positiveCue: "Good knee position"
            ),
        ],
        recommendedCameraPosition: .side,
        descentThreshold: 165,  // Knee angle drops below 165° → descent
        bottomThreshold: 140,   // Knee angle drops below 140° → bottom
        lockoutThreshold: 170   // Knee angle rises above 170° → lockout
    )

    /// Overhead Press — front view recommended.
    static let overheadPress = ExerciseFormRule(
        exerciseID: "overhead-press",
        displayName: "Overhead Press",
        checkpoints: [
            FormCheckpoint(
                name: "Arm Extension",
                jointA: "leftShoulder", jointVertex: "leftElbow", jointC: "leftWrist",
                passRange: 150...180,    // Near full extension at lockout
                cautionRange: 130...180,
                activePhases: [.ascent, .lockout],
                isPrimaryAngle: true,
                coachingCue: "Extend your arms fully",
                positiveCue: "Good lockout"
            ),
            FormCheckpoint(
                name: "Shoulder Alignment",
                jointA: "leftElbow", jointVertex: "leftShoulder", jointC: "leftHip",
                passRange: 150...180,    // Arms overhead
                cautionRange: 130...180,
                activePhases: [.lockout],
                isPrimaryAngle: false,
                coachingCue: "Press straight overhead",
                positiveCue: "Good alignment"
            ),
        ],
        recommendedCameraPosition: .front,
        descentThreshold: 160,  // Elbow angle drops below 160° → descent
        bottomThreshold: 100,   // Elbow angle drops below 100° → bottom
        lockoutThreshold: 165   // Elbow angle rises above 165° → lockout
    )

    /// All built-in form check exercises.
    static let allBuiltIn: [ExerciseFormRule] = [
        .barbellSquat,
        .conventionalDeadlift,
        .overheadPress,
    ]
}
