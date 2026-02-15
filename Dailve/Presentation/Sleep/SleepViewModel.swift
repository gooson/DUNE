import SwiftUI

@Observable
@MainActor
final class SleepViewModel {
    var todayStages: [SleepStage] = []
    var weeklyData: [DailySleep] = []
    var isLoading = false
    var errorMessage: String?

    private let sleepService = SleepQueryService()
    private let sleepScoreUseCase = CalculateSleepScoreUseCase()

    private var todayOutput: CalculateSleepScoreUseCase.Output {
        sleepScoreUseCase.execute(input: .init(stages: todayStages))
    }

    var totalSleepMinutes: Double { todayOutput.totalMinutes }
    var sleepEfficiency: Double { todayOutput.efficiency }
    var sleepScore: Int { todayOutput.score }

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
            AppLogger.ui.error("Sleep data load failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct DailySleep: Identifiable {
    let id = UUID()
    let date: Date
    let totalMinutes: Double
}
