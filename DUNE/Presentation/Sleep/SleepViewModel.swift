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
    private(set) var cachedOutput = CalculateSleepScoreUseCase.Output(score: 0, totalMinutes: 0, efficiency: 0, remRatio: 0, wasoMinutes: 0, wasoCount: 0)
    private(set) var stageBreakdown: [(stage: SleepStage.Stage, minutes: Double)] = []
    private(set) var deficitAnalysis: SleepDeficitAnalysis?
    private(set) var wasoAnalysis: WakeAfterSleepOnset?
    private(set) var breathingAnalysis: BreathingDisturbanceAnalysis?

    private let sleepService: SleepQuerying
    private let sleepScoreUseCase = CalculateSleepScoreUseCase()
    private let deficitUseCase = CalculateSleepDeficitUseCase()
    private let wasoUseCase = AnalyzeWASOUseCase()
    private let breathingService: BreathingDisturbanceQuerying

    init(
        sleepService: SleepQuerying? = nil,
        breathingService: BreathingDisturbanceQuerying? = nil
    ) {
        self.sleepService = sleepService ?? SleepQueryService(manager: .shared)
        self.breathingService = breathingService ?? BreathingDisturbanceQueryService()
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

            // Fetch weekly data and deficit data in parallel
            // Correction #115: Fetch window >= filter threshold x 2
            let deficitEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            let deficitStart = calendar.date(byAdding: .day, value: -90, to: today) ?? today

            async let weeklyTask: [DailySleep] = withThrowingTaskGroup(of: DailySleep?.self) { group in
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
            async let deficitTask = sleepService.fetchDailySleepDurations(start: deficitStart, end: deficitEnd)

            weeklyData = try await weeklyTask
            let allDurations = try await deficitTask
            computeDeficitAnalysis(from: allDurations, today: today)

            // WASO analysis from today's stages (synchronous, no additional fetch)
            wasoAnalysis = wasoUseCase.execute(stages: todayStages)

            // Load additional insights in parallel (each can fail independently)
            await loadEnhancedInsights()
        } catch {
            AppLogger.ui.error("Sleep data load failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadEnhancedInsights() async {
        do {
            let samples = try await breathingService.fetchNightlyDisturbances(days: 30)
            breathingAnalysis = breathingService.analyze(samples: samples)
        } catch {
            AppLogger.ui.error("[Sleep] Breathing disturbances fetch failed: \(error, privacy: .private)")
        }
    }

    private func computeDeficitAnalysis(
        from durations: [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])],
        today: Date
    ) {
        let calendar = Calendar.current
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today

        let recent14 = durations.filter { $0.date >= fourteenDaysAgo }.map(CalculateSleepDeficitUseCase.Input.DayDuration.init(from:))
        let longTerm90 = durations.map(CalculateSleepDeficitUseCase.Input.DayDuration.init(from:))

        deficitAnalysis = deficitUseCase.execute(input: .init(
            recentDurations: recent14,
            longTermDurations: longTerm90
        ))
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
