import Foundation

/// Workout consistency metrics: current streak, best streak, monthly stats.
struct WorkoutStreak: Sendable, Hashable {
    let currentStreak: Int
    let bestStreak: Int
    let monthlyCount: Int
    let monthlyGoal: Int

    var monthlyPercentage: Double {
        guard monthlyGoal > 0 else { return 0 }
        return min(1.0, Double(monthlyCount) / Double(monthlyGoal))
    }

    init(currentStreak: Int, bestStreak: Int, monthlyCount: Int, monthlyGoal: Int = 16) {
        self.currentStreak = max(0, currentStreak)
        self.bestStreak = max(0, bestStreak)
        self.monthlyCount = max(0, monthlyCount)
        self.monthlyGoal = max(1, monthlyGoal)
    }
}
