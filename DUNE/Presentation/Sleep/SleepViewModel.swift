import Foundation
import Observation

@Observable
@MainActor
final class SleepViewModel {
    var todayStages: [SleepStage] = []
    var weeklyData: [DailySleep] = []
    var isLoading = false
    var errorMessage: String?
    var latestSleepDate: Date?

    // Cached outputs (rebuilt in loadData — not recomputed per render)
    private(set) var cachedOutput = CalculateSleepScoreUseCase.Output(score: 0, totalMinutes: 0, efficiency: 0)
    private(set) var stageBreakdown: [(stage: SleepStage.Stage, minutes: Double)] = []

    private let sleepService: SleepQuerying
    private let sleepScoreUseCase = CalculateSleepScoreUseCase()

    init(sleepService: SleepQuerying? = nil) {
        self.sleepService = sleepService ?? SleepQueryService(manager: .shared)
    }

    var totalSleepMinutes: Double { cachedOutput.totalMinutes }
    var sleepEfficiency: Double { cachedOutput.efficiency }
    var sleepScore: Int { cachedOutput.score }

    var isShowingHistoricalData: Bool {
        guard let latestSleepDate else { return false }
        return !Calendar.current.isDateInToday(latestSleepDate)
    }

    func loadData() async {
        isLoading = true
        do {
            let calendar = Calendar.current
            let today = Date()

            // Fetch today's sleep data
            let fetchedStages = try await sleepService.fetchSleepStages(for: today)

            // Fallback: if today has no sleep data, find most recent
            if !fetchedStages.isEmpty {
                todayStages = fetchedStages
                latestSleepDate = today
            } else if let latest = try await sleepService.fetchLatestSleepStages(withinDays: 7) {
                todayStages = latest.stages
                latestSleepDate = latest.date
            } else {
                todayStages = []
                latestSleepDate = nil
            }

            // Cache sleep score (single computation instead of 3× per render)
            cachedOutput = sleepScoreUseCase.execute(input: .init(stages: todayStages))

            // Cache stage breakdown (single-pass dictionary instead of 5×O(N) per render)
            rebuildStageBreakdown()

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

    private func rebuildStageBreakdown() {
        var totals: [SleepStage.Stage: Double] = [:]
        for s in todayStages {
            totals[s.stage, default: 0] += s.duration / 60.0
        }
        // Display unspecified as separate "Asleep" entry (consistent with score calculation)
        var order: [SleepStage.Stage] = [.deep, .core]
        if totals[.unspecified, default: 0] > 0 {
            order.append(.unspecified)
        }
        order.append(contentsOf: [.rem, .awake])
        stageBreakdown = order.map { (stage: $0, minutes: totals[$0, default: 0]) }
    }
}

struct DailySleep: Identifiable {
    let id = UUID()
    let date: Date
    let totalMinutes: Double
}
