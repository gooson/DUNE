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

    // MARK: - Bodyweight Exercises

    /// Pull-up — front view recommended.
    /// Upper-body only: lower limb keypoints may be occluded on bar.
    ///
    /// Phase mapping (angle = elbow):
    ///   descent = pulling up (angle decreasing from dead hang)
    ///   bottom  = top of pull-up (angle at minimum, elbows bent)
    ///   ascent  = lowering body (angle increasing back to dead hang)
    ///   lockout = dead hang (angle at maximum, arms straight → rep counted)
    static let pullUp = ExerciseFormRule(
        exerciseID: "pull-up",
        displayName: "Pull-up",
        checkpoints: [
            FormCheckpoint(
                name: "Arm Extension",
                jointA: "leftShoulder", jointVertex: "leftElbow", jointC: "leftWrist",
                passRange: 30...80,       // Deep pull — elbows well bent at top
                cautionRange: 80...100,   // Not pulling high enough
                activePhases: [.descent, .bottom],
                isPrimaryAngle: true,
                coachingCue: "Pull higher",
                positiveCue: "Good pull"
            ),
            FormCheckpoint(
                name: "Shoulder Engagement",
                jointA: "leftElbow", jointVertex: "leftShoulder", jointC: "leftHip",
                passRange: 10...50,       // Shoulders depressed, elbows close
                cautionRange: 50...70,    // Shoulders shrugged or elbows flared
                activePhases: [.descent, .bottom],
                isPrimaryAngle: false,
                coachingCue: "Depress your shoulders",
                positiveCue: "Good shoulder position"
            ),
        ],
        recommendedCameraPosition: .front,
        descentThreshold: 155,  // Elbow angle drops below 155° → started pulling
        bottomThreshold: 80,    // Elbow angle drops below 80° → top of pull-up
        lockoutThreshold: 160   // Elbow angle rises above 160° → dead hang (rep counted)
    )

    /// Bodyweight Squat — side view recommended.
    static let bodyweightSquat = ExerciseFormRule(
        exerciseID: "bodyweight-squat",
        displayName: "Bodyweight Squat",
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
                name: "Torso Upright",
                jointA: "leftShoulder", jointVertex: "leftHip", jointC: "leftKnee",
                passRange: 50...80,      // More upright than barbell (no bar load)
                cautionRange: 40...90,
                activePhases: [.descent, .bottom, .ascent],
                isPrimaryAngle: false,
                coachingCue: "Stay upright",
                positiveCue: "Good posture"
            ),
        ],
        recommendedCameraPosition: .side,
        descentThreshold: 160,
        bottomThreshold: 110,
        lockoutThreshold: 165
    )

    /// Lunge — side view recommended (front leg visible).
    static let lunge = ExerciseFormRule(
        exerciseID: "lunge",
        displayName: "Lunge",
        checkpoints: [
            FormCheckpoint(
                name: "Front Knee",
                jointA: "leftHip", jointVertex: "leftKnee", jointC: "leftAnkle",
                passRange: 80...100,     // ~90° at bottom
                cautionRange: 70...110,
                activePhases: [.descent, .bottom],
                isPrimaryAngle: true,
                coachingCue: "Bend to 90 degrees",
                positiveCue: "Good knee angle"
            ),
            FormCheckpoint(
                name: "Torso Upright",
                jointA: "leftShoulder", jointVertex: "leftHip", jointC: "leftKnee",
                passRange: 60...100,     // Upright torso
                cautionRange: 50...110,
                activePhases: [.descent, .bottom, .ascent],
                isPrimaryAngle: false,
                coachingCue: "Keep your torso upright",
                positiveCue: "Good torso position"
            ),
        ],
        recommendedCameraPosition: .side,
        descentThreshold: 155,  // Knee angle drops below 155° → descent
        bottomThreshold: 105,   // Knee angle drops below 105° → bottom
        lockoutThreshold: 160   // Knee angle rises above 160° → lockout
    )

    /// All built-in form check exercises.
    static let allBuiltIn: [ExerciseFormRule] = [
        .barbellSquat,
        .conventionalDeadlift,
        .overheadPress,
        .pullUp,
        .bodyweightSquat,
        .lunge,
    ]
}
