import Foundation

// MARK: - Checkpoint Result

/// Result of evaluating a single form checkpoint at a point in time.
struct CheckpointResult: Sendable, Identifiable {
    var id: String { checkpointName }

    let checkpointName: String
    /// Whether this checkpoint is meant to be evaluated in the current phase.
    let isActivePhase: Bool
    let status: PostureStatus
    let currentDegrees: Double
}

// MARK: - Exercise Form State

/// Observable state for exercise form checking during realtime analysis.
struct ExerciseFormState: Sendable {
    /// Currently active exercise rule.
    let exerciseID: String

    /// Current phase of the repetition.
    var currentPhase: ExercisePhase = .setup

    /// Latest checkpoint evaluation results.
    var checkpointResults: [CheckpointResult] = []

    /// Number of completed repetitions.
    var repCount: Int = 0

    /// Cumulative score across all checkpoints in the current rep (0-100).
    var currentRepScore: Int = 0

    /// Average score across all completed reps (0-100).
    var averageScore: Int = 0

    /// Whether form analysis is actively running.
    var isActive: Bool = true
}

// MARK: - Rep Summary

/// Summary of a single completed rep for history tracking.
struct RepSummary: Sendable {
    let repNumber: Int
    let score: Int
    let worstCheckpoint: String?
}
