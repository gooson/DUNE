import Foundation

/// Analyzes exercise form from 2D keypoints in realtime.
///
/// Pure geometry — no Vision, UI, or AVFoundation dependencies.
/// Designed to be called once per frame from `RealtimePoseTracker`.
/// - Note: Not inherently thread-safe. Caller (RealtimePoseTracker) must serialize access.
final class ExerciseFormAnalyzer: @unchecked Sendable {

    // MARK: - Configuration

    /// Number of consecutive frames in the same direction to confirm a phase transition.
    private static let phaseDebounceFrames = 5

    // MARK: - State (caller must synchronize access)

    private let rule: ExerciseFormRule
    private var currentPhase: ExercisePhase = .setup
    private var repCount: Int = 0
    private var repScores: [Int] = []  // Scores per completed rep
    private var currentRepCheckpointScores: [Int] = []

    // Phase detection state
    private var primaryAngleHistory: [Double] = []  // Last N primary angle values
    private var previousPrimaryAngle: Double?
    private var consecutiveDescentFrames: Int = 0
    private var consecutiveAscentFrames: Int = 0
    private var reachedBottom: Bool = false

    // MARK: - Init

    init(rule: ExerciseFormRule) {
        self.rule = rule
    }

    // MARK: - Public API

    /// Process a single frame of 2D keypoints.
    /// Returns the updated form state.
    func processFrame(keypoints: [(String, CGPoint)]) -> ExerciseFormState {
        let kp = Dictionary(keypoints, uniquingKeysWith: { _, last in last })

        // Evaluate all checkpoints
        var results: [CheckpointResult] = []
        var primaryAngle: Double?

        for checkpoint in rule.checkpoints {
            guard let a = kp[checkpoint.jointA],
                  let vertex = kp[checkpoint.jointVertex],
                  let c = kp[checkpoint.jointC] else {
                results.append(CheckpointResult(
                    checkpointName: checkpoint.name,
                    status: .unmeasurable,
                    currentDegrees: 0
                ))
                continue
            }

            let degrees = Self.angle2D(a: a, vertex: vertex, c: c)
            guard degrees.isFinite else {
                results.append(CheckpointResult(
                    checkpointName: checkpoint.name,
                    status: .unmeasurable,
                    currentDegrees: 0
                ))
                continue
            }

            if checkpoint.isPrimaryAngle {
                primaryAngle = degrees
            }

            let status: PostureStatus
            if checkpoint.activePhases.contains(currentPhase) {
                status = checkpoint.evaluate(degrees: degrees)
            } else {
                // Checkpoint not active in current phase — show as normal (not evaluated)
                status = .normal
            }

            results.append(CheckpointResult(
                checkpointName: checkpoint.name,
                status: status,
                currentDegrees: degrees
            ))
        }

        // Update phase based on primary angle
        if let angle = primaryAngle {
            updatePhase(primaryAngle: angle)
        }

        // Score the current frame's active checkpoints
        let activeResults = results.filter { result in
            rule.checkpoints.first { $0.name == result.checkpointName }?
                .activePhases.contains(currentPhase) == true
                && result.status != .unmeasurable
        }
        if !activeResults.isEmpty {
            let frameScore = Self.scoreFromResults(activeResults)
            currentRepCheckpointScores.append(frameScore)
        }

        let currentRepScore: Int
        if currentRepCheckpointScores.isEmpty {
            currentRepScore = 0
        } else {
            currentRepScore = currentRepCheckpointScores.reduce(0, +) / currentRepCheckpointScores.count
        }

        let averageScore: Int
        if repScores.isEmpty {
            averageScore = currentRepScore
        } else {
            averageScore = repScores.reduce(0, +) / repScores.count
        }

        return ExerciseFormState(
            exerciseID: rule.exerciseID,
            currentPhase: currentPhase,
            checkpointResults: results,
            repCount: repCount,
            currentRepScore: currentRepScore,
            averageScore: averageScore
        )
    }

    /// Reset all state (e.g., when camera switches).
    func reset() {
        currentPhase = .setup
        repCount = 0
        repScores = []
        currentRepCheckpointScores = []
        primaryAngleHistory = []
        previousPrimaryAngle = nil
        consecutiveDescentFrames = 0
        consecutiveAscentFrames = 0
        reachedBottom = false
    }

    // MARK: - Phase Detection

    private func updatePhase(primaryAngle: Double) {
        defer { previousPrimaryAngle = primaryAngle }
        guard let prev = previousPrimaryAngle else { return }

        let delta = primaryAngle - prev

        // Track descent/ascent trends
        if delta < -0.5 {
            // Angle decreasing → descent
            consecutiveDescentFrames += 1
            consecutiveAscentFrames = 0
        } else if delta > 0.5 {
            // Angle increasing → ascent
            consecutiveAscentFrames += 1
            consecutiveDescentFrames = 0
        }
        // Small changes (|delta| <= 0.5) don't reset counters — holding position

        switch currentPhase {
        case .setup, .lockout:
            // Transition to descent when angle drops below threshold
            if primaryAngle < rule.descentThreshold,
               consecutiveDescentFrames >= Self.phaseDebounceFrames {
                currentPhase = .descent
                reachedBottom = false
                if currentPhase == .lockout {
                    // New rep cycle starting — record previous rep
                    finalizeRep()
                }
            }

        case .descent:
            if primaryAngle < rule.bottomThreshold {
                currentPhase = .bottom
                reachedBottom = true
            }

        case .bottom:
            if consecutiveAscentFrames >= Self.phaseDebounceFrames,
               primaryAngle > rule.bottomThreshold {
                currentPhase = .ascent
            }

        case .ascent:
            if primaryAngle > rule.lockoutThreshold,
               consecutiveAscentFrames >= Self.phaseDebounceFrames {
                currentPhase = .lockout
                if reachedBottom {
                    finalizeRep()
                    reachedBottom = false
                }
            }
        }
    }

    private func finalizeRep() {
        repCount += 1
        let repScore: Int
        if currentRepCheckpointScores.isEmpty {
            repScore = 0
        } else {
            repScore = currentRepCheckpointScores.reduce(0, +) / currentRepCheckpointScores.count
        }
        repScores.append(repScore)
        currentRepCheckpointScores = []
    }

    // MARK: - Geometry

    /// 2D angle in degrees at vertex formed by points a, vertex, c.
    static func angle2D(a: CGPoint, vertex: CGPoint, c: CGPoint) -> Double {
        let ba = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let bc = CGVector(dx: c.x - vertex.x, dy: c.y - vertex.y)

        let dot = ba.dx * bc.dx + ba.dy * bc.dy
        let magA = sqrt(ba.dx * ba.dx + ba.dy * ba.dy)
        let magC = sqrt(bc.dx * bc.dx + bc.dy * bc.dy)
        guard magA > 0, magC > 0 else { return 0 }

        let cosAngle = max(-1, min(1, dot / (magA * magC)))
        return acos(cosAngle) * (180.0 / .pi)
    }

    /// Score 0-100 from checkpoint evaluation results.
    private static func scoreFromResults(_ results: [CheckpointResult]) -> Int {
        guard !results.isEmpty else { return 0 }
        var total = 0
        for result in results {
            switch result.status {
            case .normal: total += 100
            case .caution: total += 60
            case .warning: total += 30
            case .unmeasurable: total += 0
            }
        }
        return total / results.count
    }
}
