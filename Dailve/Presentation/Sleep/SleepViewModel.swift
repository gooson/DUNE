import SwiftUI

@Observable
@MainActor
final class SleepViewModel {
    var todayStages: [SleepStage] = []
    var weeklyData: [DailySleep] = []
    var isLoading = false
    var errorMessage: String?

    private let sleepService = SleepQueryService()

    var totalSleepMinutes: Double {
        todayStages
            .filter { $0.stage != .awake }
            .map(\.duration)
            .reduce(0, +) / 60.0
    }

    var sleepEfficiency: Double {
        let totalTime = todayStages.map(\.duration).reduce(0, +)
        let sleepTime = todayStages.filter { $0.stage != .awake }.map(\.duration).reduce(0, +)
        guard totalTime > 0 else { return 0 }
        return (sleepTime / totalTime) * 100
    }

    var sleepScore: Int {
        calculateSleepScore()
    }

    var stageBreakdown: [(stage: SleepStage.Stage, minutes: Double)] {
        let stages: [SleepStage.Stage] = [.deep, .core, .rem, .awake]
        return stages.map { stage in
            let minutes = todayStages
                .filter { $0.stage == stage }
                .map(\.duration)
                .reduce(0, +) / 60.0
            return (stage: stage, minutes: minutes)
        }
    }

    func loadData() async {
        isLoading = true
        do {
            let calendar = Calendar.current
            let today = Date()

            // Parallel: fetch today + 7 days concurrently
            todayStages = try await sleepService.fetchSleepStages(for: today)

            weeklyData = try await withThrowingTaskGroup(of: DailySleep?.self) { group in
                for dayOffset in 0..<7 {
                    group.addTask { [sleepService] in
                        guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
                        let stages = try await sleepService.fetchSleepStages(for: date)
                        let totalMinutes = stages.filter { $0.stage != .awake }.map(\.duration).reduce(0, +) / 60.0
                        return DailySleep(date: date, totalMinutes: totalMinutes)
                    }
                }
                var results: [DailySleep] = []
                for try await result in group {
                    if let result { results.append(result) }
                }
                return results.sorted { $0.date < $1.date }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func calculateSleepScore() -> Int {
        guard totalSleepMinutes > 0 else { return 0 }

        // Duration score (0-40): 7-9 hours ideal
        let durationScore: Double
        let hours = totalSleepMinutes / 60
        if hours >= 7 && hours <= 9 {
            durationScore = 40
        } else if hours >= 6 || hours <= 10 {
            durationScore = 30
        } else {
            durationScore = max(0, 40 - abs(hours - 8) * 10)
        }

        // Deep sleep ratio score (0-30): 15-25% ideal
        let deepMinutes = todayStages.filter { $0.stage == .deep }.map(\.duration).reduce(0, +) / 60.0
        let deepRatio = deepMinutes / totalSleepMinutes
        let deepScore: Double
        if deepRatio >= 0.15 && deepRatio <= 0.25 {
            deepScore = 30
        } else {
            deepScore = max(0, 30 - abs(deepRatio - 0.20) * 150)
        }

        // Efficiency score (0-30)
        let efficiencyScore = min(30, sleepEfficiency / 100 * 30)

        return Int(min(100, durationScore + deepScore + efficiencyScore))
    }
}

struct DailySleep: Identifiable {
    let id = UUID()
    let date: Date
    let totalMinutes: Double
}
