import Foundation

/// A single rep-max entry: best weight at a specific rep count.
struct RepMaxEntry: Sendable, Hashable {
    let reps: Int  // e.g. 3, 5, 10
    let weight: Double
    let date: Date
}

/// Personal record for a strength exercise.
/// Tracks max weight, estimated 1RM, rep-range PRs, and session volume.
struct StrengthPersonalRecord: Sendable, Hashable, Identifiable {
    let id: String  // exerciseDefinitionID or exerciseType
    let exerciseName: String
    let maxWeight: Double
    let date: Date
    let isRecent: Bool  // Updated within last 7 days

    /// Estimated 1RM via Epley formula (best across all sessions).
    let estimated1RM: Double?
    /// Date of the session that produced the best 1RM.
    let estimated1RMDate: Date?

    /// Per-rep-count best weights (e.g. 3RM, 5RM, 10RM).
    let repMaxEntries: [RepMaxEntry]

    /// Best single-session total volume (Σ weight×reps) for this exercise.
    let bestSessionVolume: Double?
    /// Date of the session that produced the best volume.
    let bestSessionVolumeDate: Date?

    init(
        exerciseName: String,
        maxWeight: Double,
        date: Date,
        referenceDateForRecent: Date = Date(),
        estimated1RM: Double? = nil,
        estimated1RMDate: Date? = nil,
        repMaxEntries: [RepMaxEntry] = [],
        bestSessionVolume: Double? = nil,
        bestSessionVolumeDate: Date? = nil
    ) {
        self.id = exerciseName
        self.exerciseName = exerciseName
        self.maxWeight = max(0, min(500, maxWeight))  // Correction #22: weight 0-500
        self.date = date

        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: date, to: referenceDateForRecent).day ?? 0
        self.isRecent = daysDiff >= 0 && daysDiff <= 7

        self.estimated1RM = estimated1RM.map { max(0, min(750, $0)) }
        self.estimated1RMDate = estimated1RMDate
        self.repMaxEntries = repMaxEntries
        self.bestSessionVolume = bestSessionVolume.map { max(0, min(100_000, $0)) }
        self.bestSessionVolumeDate = bestSessionVolumeDate
    }
}
