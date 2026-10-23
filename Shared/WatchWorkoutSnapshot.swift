import Foundation

/// Small, versioned payload used only by the mirrored workout and its Live Activity.
struct WatchWorkoutSnapshot: Codable, Hashable, Sendable {
    enum Phase: String, Codable, Sendable {
        case running, paused, ended
    }

    var startedAt: Date
    var updatedAt: Date
    var exerciseName: String
    var elapsedSeconds: TimeInterval
    var phase: Phase
    var heartRate: Double?
    var activeCalories: Double
    var distanceMeters: Double

    var isValid: Bool {
        startedAt.timeIntervalSince1970.isFinite
            && updatedAt.timeIntervalSince1970.isFinite
            && updatedAt >= startedAt
            && !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && exerciseName.count <= 200
            && elapsedSeconds.isFinite && (0...172_800).contains(elapsedSeconds)
            && activeCalories.isFinite && (0...100_000).contains(activeCalories)
            && distanceMeters.isFinite && (0...1_000_000).contains(distanceMeters)
            && (heartRate == nil || heartRate.map { $0.isFinite && (20...250).contains($0) } == true)
    }

    /// A running system timer advances without a per-second transport update.
    var timerStartDate: Date { updatedAt.addingTimeInterval(-elapsedSeconds) }

    func elapsed(at date: Date) -> TimeInterval {
        elapsedSeconds + (phase == .running ? max(0, date.timeIntervalSince(updatedAt)) : 0)
    }
}
