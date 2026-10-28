import Foundation
import Testing
import UIKit
@testable import DUNE

@Suite("WorkoutAchievementBoardModel")
struct WorkoutAchievementBoardTests {
    @Test("Groups rules in board order and retains zero-value strength rules")
    func groupingAndZeroStrength() {
        let metrics = [
            metric("weeklyRunning15km", value: 0, target: 15),
            metric("weeklyChest3", value: 0, target: 3),
            metric("weeklyWorkout7", value: 4, target: 7),
            metric("weeklyStrength3", value: 2, target: 3),
            metric("weeklyWorkout5", value: 4, target: 5),
            metric("weeklyBack3", value: 1, target: 3),
            metric("weeklyLowerBody3", value: 0, target: 3),
            metric("weeklyShoulders3", value: 1, target: 3),
            metric("weeklyArms3", value: 2, target: 3)
        ]

        let board = WorkoutAchievementBoardModel(customGoals: [], metrics: metrics)

        #expect(board.groups.map(\.id) == ["routine", "strength", "running"])
        #expect(board.groups[1].metrics.map(\.id) == WorkoutAchievementBoardModel.strengthIDs)
        #expect(board.totalCount == 9)
        #expect(board.completedCount == 0)
    }

    @Test("Total includes each custom goal and completed count respects its state")
    func dynamicGoalDenominator() {
        let board = WorkoutAchievementBoardModel(
            customGoals: [goal("First", completed: true), goal("Second", completed: false)],
            metrics: [metric("weeklyWorkout5", value: 6, target: 5, completed: true)]
        )

        #expect(board.totalCount == 3)
        #expect(board.completedCount == 2)
        #expect(board.challengeCount == 1)
        #expect(board.challengeCompletedCount == 1)
    }

    @Test("Visual ratio clamps zero, over-target, and nonfinite values")
    func boundedFraction() {
        #expect(WorkoutAchievementBoardModel.fraction(current: 0, target: 0) == 0)
        #expect(WorkoutAchievementBoardModel.fraction(current: -2, target: 5) == 0)
        #expect(WorkoutAchievementBoardModel.fraction(current: 12, target: 5) == 1)
        #expect(WorkoutAchievementBoardModel.fraction(current: .nan, target: 5) == 0)
        #expect(WorkoutAchievementBoardModel.fraction(current: .infinity, target: 5) == 0)
        #expect(WorkoutAchievementBoardModel.fraction(current: 3, target: .infinity) == 0)
        #expect(WorkoutAchievementBoardModel.safeValue(.nan) == 0)
        #expect(WorkoutAchievementBoardModel.safeValue(-7) == 0)
        #expect(WorkoutAchievementBoardModel.display(.infinity) == WorkoutAchievementBoardModel.display(0))
    }

    @Test("Missing rule groups are omitted instead of synthesized")
    func missingGroups() {
        let board = WorkoutAchievementBoardModel(customGoals: [], metrics: [])
        #expect(board.groups.isEmpty)
        #expect(board.totalCount == 0)
        #expect(board.completedCount == 0)
    }

    @Test("Strength marks clamp malformed targets before integer conversion")
    func safeStrengthMarks() {
        #expect(WorkoutAchievementBoardModel.strengthMarkCount(target: -.greatestFiniteMagnitude) == 0)
        #expect(WorkoutAchievementBoardModel.strengthMarkCount(target: -3) == 0)
        #expect(WorkoutAchievementBoardModel.strengthMarkCount(target: .nan) == 0)
        #expect(WorkoutAchievementBoardModel.strengthMarkCount(target: .infinity) == 0)
        #expect(WorkoutAchievementBoardModel.strengthMarkCount(target: .greatestFiniteMagnitude) == 3)
        for target in 0...3 {
            #expect(WorkoutAchievementBoardModel.strengthMarkCount(target: Double(target)) == target)
        }
    }

    @Test("More than twelve goals retain the real incomplete total")
    func manyGoals() {
        let goals = (0..<13).map { goal("Goal \($0)", completed: $0 < 12) }
        let board = WorkoutAchievementBoardModel(customGoals: goals, metrics: [])
        #expect(board.totalCount == 13)
        #expect(board.completedCount == 12)
        #expect(WorkoutAchievementBoardModel.fraction(current: Double(board.completedCount), target: Double(board.totalCount)) < 1)
    }

    @Test("Board symbols resolve on the target OS")
    func symbolsResolve() {
        let names = ["figure.run", "trophy", "star.fill", "chevron.down",
                     "calendar.badge.clock", "dumbbell.fill", "flame.fill",
                     "circle", "checkmark.circle.fill"]
        #expect(names.allSatisfy { UIImage(systemName: $0) != nil })
    }

    private func metric(_ id: String, value: Double, target: Double, completed: Bool = false) -> LifeAutoAchievementProgress {
        LifeAutoAchievementProgress(id: id, title: id, currentValue: value, targetValue: target,
                                    unit: "workouts", isCompleted: completed, streakWeeks: 0)
    }

    private func goal(_ name: String, completed: Bool) -> HabitProgress {
        HabitProgress(
            id: UUID(), name: name, iconCategory: .fitness, type: .check,
            goalValue: 1, goalUnit: nil, frequency: .daily, todayValue: completed ? 1 : 0,
            isCompleted: completed, streak: 0, isAutoLinked: true, isAutoCompleted: completed,
            isCycleBased: false, canCompleteCycle: false, nextDueDate: nil, cycleStartDate: nil,
            cycleStartPoint: nil, isScheduled: true, isDue: true, isOverdue: false,
            lastCycleAction: nil, historyCount: 0, timeOfDay: .anytime
        )
    }
}
