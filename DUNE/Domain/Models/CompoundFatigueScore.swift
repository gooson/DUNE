import Foundation

/// Per-muscle compound fatigue score combining workout load, sleep, and HRV modifiers.
struct CompoundFatigueScore: Sendable {
    let muscle: MuscleGroup
    /// Normalized fatigue score: 0.0 (fully recovered) to 1.0 (overtrained).
    let normalizedScore: Double
    let level: FatigueLevel
    let breakdown: FatigueBreakdown
}

/// Detailed breakdown of how a compound fatigue score was calculated.
/// Used to populate the info sheet for transparency.
struct FatigueBreakdown: Sendable {
    /// Each workout's contribution to this muscle's fatigue.
    let workoutContributions: [WorkoutContribution]
    /// Raw accumulated fatigue before modifier adjustment.
    let baseFatigue: Double
    /// Sleep-derived recovery modifier (0.5...1.25). Higher = faster recovery.
    let sleepModifier: Double
    /// HRV/RHR-derived readiness modifier (0.6...1.20). Higher = faster recovery.
    let readinessModifier: Double
    /// Effective time constant used for decay (hours).
    let effectiveTau: Double
}

/// A single workout session's contribution to muscle fatigue.
struct WorkoutContribution: Sendable, Identifiable {
    let id = UUID()
    let date: Date
    let exerciseName: String?
    /// Raw load before time decay.
    let rawLoad: Double
    /// Remaining load after exponential decay.
    let decayedLoad: Double
}
