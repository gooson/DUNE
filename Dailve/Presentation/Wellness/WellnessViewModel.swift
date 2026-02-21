import Foundation
import Observation

// MARK: - WellnessViewModel

@Observable
@MainActor
final class WellnessViewModel {
    // MARK: - Published State

    var wellnessScore: WellnessScore?
    var physicalCards: [VitalCardData] = []
    var activeCards: [VitalCardData] = []

    var isLoading = false
    var partialFailureMessage: String?

    // Sleep sub-state (consumed by hero card)
    var sleepScore: Int?
    var conditionScore: Int?
    var bodyScore: Int?

    // Full condition score for detail navigation
    var conditionScoreFull: ConditionScore?

    // MARK: - Dependencies

    private let sleepService: SleepQuerying
    private let bodyService: BodyCompositionQuerying
    private let hrvService: HRVQuerying
    private let vitalsService: VitalsQuerying
    private let heartRateService: HeartRateQuerying
    private let wellnessScoreUseCase: WellnessScoreCalculating
    private let sleepScoreUseCase: SleepScoreCalculating
    private let conditionScoreUseCase: ConditionScoreCalculating

    // MARK: - Internal State

    private var loadTask: Task<Void, Never>?
    private static let staleDays = 3

    // MARK: - Init

    init(
        sleepService: SleepQuerying? = nil,
        bodyService: BodyCompositionQuerying? = nil,
        hrvService: HRVQuerying? = nil,
        vitalsService: VitalsQuerying? = nil,
        heartRateService: HeartRateQuerying? = nil,
        wellnessScoreUseCase: WellnessScoreCalculating? = nil,
        sleepScoreUseCase: SleepScoreCalculating? = nil,
        conditionScoreUseCase: ConditionScoreCalculating? = nil
    ) {
        let manager = HealthKitManager.shared
        self.sleepService = sleepService ?? SleepQueryService(manager: manager)
        self.bodyService = bodyService ?? BodyCompositionQueryService(manager: manager)
        self.hrvService = hrvService ?? HRVQueryService(manager: manager)
        self.vitalsService = vitalsService ?? VitalsQueryService(manager: manager)
        self.heartRateService = heartRateService ?? HeartRateQueryService(manager: manager)
        self.wellnessScoreUseCase = wellnessScoreUseCase ?? CalculateWellnessScoreUseCase()
        self.sleepScoreUseCase = sleepScoreUseCase ?? CalculateSleepScoreUseCase()
        self.conditionScoreUseCase = conditionScoreUseCase ?? CalculateConditionScoreUseCase()
    }

    // MARK: - Public

    func loadData() {
        // Cancel-before-spawn (Correction #16)
        loadTask?.cancel()
        loadTask = Task { await performLoad() }
    }

    /// Async entry point for `.refreshable` — awaits load completion so spinner persists.
    func performRefresh() async {
        loadTask?.cancel()
        let task = Task { await performLoad() }
        loadTask = task
        await task.value
    }

    // MARK: - Loading

    private func performLoad() async {
        isLoading = true
        partialFailureMessage = nil

        // Collect results using TaskGroup for 10+ parallel queries (Correction #5)
        let results = await fetchAllData()

        guard !Task.isCancelled else { // Correction #17
            isLoading = false
            return
        }

        // Build cards from results
        var cards: [VitalCardData] = []

        // --- Sleep ---
        if let sleep = results.sleep {
            sleepScore = sleep.score
            let sparkline = results.sleepWeekly.map(\.totalMinutes)
            cards.append(buildCard(
                category: .sleep,
                title: "Sleep",
                rawValue: sleep.totalMinutes,
                formattedValue: Self.formatSleepMinutes(sleep.totalMinutes),
                unit: "",
                change: nil,
                sparkline: sparkline,
                date: results.sleepDate ?? Date(),
                isHistorical: results.sleepIsHistorical
            ))
        } else {
            sleepScore = nil
        }

        // --- Condition (HRV/RHR) ---
        if let condition = results.condition {
            conditionScore = condition.score
            conditionScoreFull = condition
        } else {
            conditionScore = nil
            conditionScoreFull = nil
        }

        // --- HRV ---
        if let hrv = results.latestHRV {
            let sparkline = results.hrvWeekly.map(\.value)
            cards.append(buildCard(
                category: .hrv,
                title: "HRV",
                rawValue: hrv.value,
                formattedValue: String(format: "%.0f", hrv.value),
                unit: "ms",
                change: nil,
                sparkline: sparkline,
                date: hrv.date,
                isHistorical: false
            ))
        }

        // --- RHR ---
        if let rhr = results.latestRHR {
            let sparkline = results.rhrWeekly.map(\.value)
            cards.append(buildCard(
                category: .rhr,
                title: "Resting HR",
                rawValue: rhr.value,
                formattedValue: String(format: "%.0f", rhr.value),
                unit: "bpm",
                change: nil,
                sparkline: sparkline,
                date: rhr.date,
                isHistorical: false
            ))
        }

        // --- Body Composition (Weight) ---
        if let weight = results.latestWeight {
            let change = results.weightWeekAgo.map { weight.value - $0 }
            let sparkline = results.weightHistory.map(\.value)
            cards.append(buildCard(
                category: .weight,
                title: "Weight",
                rawValue: weight.value,
                formattedValue: String(format: "%.1f", weight.value),
                unit: "kg",
                change: change,
                sparkline: sparkline,
                date: weight.date,
                isHistorical: false
            ))
        }

        // --- BMI ---
        if let bmi = results.latestBMI {
            cards.append(buildCard(
                category: .bmi,
                title: "BMI",
                rawValue: bmi.value,
                formattedValue: String(format: "%.1f", bmi.value),
                unit: "",
                change: nil,
                sparkline: [],
                date: bmi.date,
                isHistorical: false
            ))
        }

        // --- Body Fat ---
        if let bf = results.latestBodyFat {
            let sparkline = results.bodyFatHistory.map(\.value)
            cards.append(buildCard(
                category: .bodyFat,
                title: "Body Fat",
                rawValue: bf.value,
                formattedValue: String(format: "%.1f", bf.value),
                unit: "%",
                change: nil,
                sparkline: sparkline,
                date: bf.date,
                isHistorical: false
            ))
        }

        // --- Lean Body Mass ---
        if let lbm = results.latestLeanBodyMass {
            cards.append(buildCard(
                category: .leanBodyMass,
                title: "Lean Body Mass",
                rawValue: lbm.value,
                formattedValue: String(format: "%.1f", lbm.value),
                unit: "kg",
                change: nil,
                sparkline: [],
                date: lbm.date,
                isHistorical: false
            ))
        }

        // --- Heart Rate (general) ---
        if let hr = results.latestHeartRate {
            let sparkline = results.heartRateHistory.map(\.value)
            cards.append(buildCard(
                category: .heartRate,
                title: "Heart Rate",
                rawValue: hr.value,
                formattedValue: String(format: "%.0f", hr.value),
                unit: "bpm",
                change: nil,
                sparkline: sparkline,
                date: hr.date,
                isHistorical: false
            ))
        }

        // --- SpO2 (HealthKit returns decimal fraction: 0.98 = 98%) ---
        if let spo2 = results.latestSpO2 {
            let displayValue = spo2.value * 100
            let sparkline = results.spo2History.map { $0.value * 100 }
            cards.append(buildCard(
                category: .spo2,
                title: "Blood Oxygen",
                rawValue: displayValue,
                formattedValue: String(format: "%.0f", displayValue),
                unit: "%",
                change: nil,
                sparkline: sparkline,
                date: spo2.date,
                isHistorical: false
            ))
        }

        // --- Respiratory Rate ---
        if let resp = results.latestRespRate {
            let sparkline = results.respRateHistory.map(\.value)
            cards.append(buildCard(
                category: .respiratoryRate,
                title: "Respiratory Rate",
                rawValue: resp.value,
                formattedValue: String(format: "%.0f", resp.value),
                unit: "breaths/min",
                change: nil,
                sparkline: sparkline,
                date: resp.date,
                isHistorical: false
            ))
        }

        // --- VO2 Max ---
        if let vo2 = results.latestVO2Max {
            let sparkline = results.vo2MaxHistory.map(\.value)
            cards.append(buildCard(
                category: .vo2Max,
                title: "VO2 Max",
                rawValue: vo2.value,
                formattedValue: String(format: "%.1f", vo2.value),
                unit: "ml/kg/min",
                change: nil,
                sparkline: sparkline,
                date: vo2.date,
                isHistorical: false
            ))
        }

        // --- HR Recovery ---
        if let hrr = results.latestHRRecovery {
            let sparkline = results.hrRecoveryHistory.map(\.value)
            cards.append(buildCard(
                category: .heartRateRecovery,
                title: "HR Recovery",
                rawValue: hrr.value,
                formattedValue: String(format: "%.0f", hrr.value),
                unit: "bpm",
                change: nil,
                sparkline: sparkline,
                date: hrr.date,
                isHistorical: false
            ))
        }

        // --- Wrist Temperature ---
        if let temp = results.latestWristTemp, let baseline = results.wristTempBaseline {
            let delta = temp.value - baseline
            let sparkline = results.wristTempHistory.map { $0.value - baseline }
            cards.append(buildCard(
                category: .wristTemperature,
                title: "Wrist Temp",
                rawValue: delta,
                formattedValue: String(format: "%+.1f", delta),
                unit: "°C",
                change: nil,
                sparkline: sparkline,
                date: temp.date,
                isHistorical: false
            ))
        }

        guard !Task.isCancelled else {
            isLoading = false
            return
        }

        // --- Body Trend for Wellness Score ---
        let bodyTrend = buildBodyTrend(results: results)
        bodyScore = bodyTrend?.score

        // --- Compute Wellness Score ---
        wellnessScore = wellnessScoreUseCase.execute(input: .init(
            sleepScore: sleepScore,
            conditionScore: conditionScore,
            bodyTrend: bodyTrend
        ))

        // Sort and split into sections (Correction #88: atomic update)
        let sortedCards = cards.sorted { a, b in
            if a.isStale != b.isStale { return !a.isStale }
            return a.lastUpdated > b.lastUpdated
        }
        physicalCards = sortedCards.filter { $0.section == .physical }
        activeCards = sortedCards.filter { $0.section == .active }

        // Partial failure message (Correction #25) — only for actual fetch errors, not missing data
        let primarySources: Set<FetchKey> = [.sleep, .condition, .weight, .heartRate, .spo2, .respRate, .vo2Max, .hrRecovery, .wristTemp]
        let failedSources = results.errorKeys.intersection(primarySources)
        if !failedSources.isEmpty, failedSources.count < primarySources.count {
            partialFailureMessage = "Some data could not be loaded (\(failedSources.count) of \(primarySources.count) sources)"
        }

        isLoading = false
    }

    // MARK: - Parallel Fetch

    private struct FetchResults: Sendable {
        // Error tracking: only actual fetch errors, not "no data available"
        var errorKeys: Set<FetchKey> = []
        // Sleep
        var sleep: CalculateSleepScoreUseCase.Output?
        var sleepDate: Date?
        var sleepIsHistorical: Bool = false
        var sleepWeekly: [DailySleep] = []
        // Condition
        var condition: ConditionScore?
        // HRV / RHR (raw values for individual cards)
        var latestHRV: VitalSample?
        var latestRHR: VitalSample?
        var hrvWeekly: [VitalSample] = []
        var rhrWeekly: [VitalSample] = []
        // Heart Rate (general, non-workout)
        var latestHeartRate: VitalSample?
        var heartRateHistory: [VitalSample] = []
        // Body
        var latestWeight: VitalSample?
        var weightWeekAgo: Double?
        var weightHistory: [BodyCompositionSample] = []
        var latestBMI: VitalSample?
        var latestBodyFat: VitalSample?
        var bodyFatHistory: [BodyCompositionSample] = []
        var latestLeanBodyMass: VitalSample?
        // Vitals
        var latestSpO2: VitalSample?
        var spo2History: [VitalSample] = []
        var latestRespRate: VitalSample?
        var respRateHistory: [VitalSample] = []
        var latestVO2Max: VitalSample?
        var vo2MaxHistory: [VitalSample] = []
        var latestHRRecovery: VitalSample?
        var hrRecoveryHistory: [VitalSample] = []
        var latestWristTemp: VitalSample?
        var wristTempBaseline: Double?
        var wristTempHistory: [VitalSample] = []
    }

    private enum FetchKey: Sendable {
        case sleep
        case sleepWeekly
        case condition
        case hrvWeekly
        case rhrWeekly
        case heartRate
        case heartRateHistory
        case weight
        case weightHistory
        case bmi
        case bodyFat
        case bodyFatHistory
        case leanBodyMass
        case spo2
        case spo2History
        case respRate
        case respRateHistory
        case vo2Max
        case vo2MaxHistory
        case hrRecovery
        case hrRecoveryHistory
        case wristTemp
        case wristTempBaseline
        case wristTempHistory
    }

    private enum FetchValue: Sendable {
        case sleepResult(output: CalculateSleepScoreUseCase.Output?, date: Date?, isHistorical: Bool)
        case sleepWeekly([DailySleep])
        case conditionResult(score: ConditionScore?, latestHRV: VitalSample?, latestRHR: VitalSample?)
        case hrvWeeklyResult([VitalSample])
        case rhrWeeklyResult([VitalSample])
        case vitalSample(VitalSample?)
        case vitalHistory([VitalSample])
        case weightHistoryResult([BodyCompositionSample])
        case bodyCompositionHistory([BodyCompositionSample])
        case baselineResult(Double?)
        case empty
        case fetchError
    }

    private func fetchAllData() async -> FetchResults {
        var results = FetchResults()

        await withTaskGroup(of: (FetchKey, FetchValue).self) { [
            sleepService, bodyService, hrvService, vitalsService, heartRateService,
            sleepScoreUseCase, conditionScoreUseCase
        ] group in

            // --- Sleep ---
            group.addTask {
                guard !Task.isCancelled else { return (.sleep, .empty) }
                do {
                    let today = Date()
                    var stages = try await sleepService.fetchSleepStages(for: today)
                    var sleepDate: Date? = today
                    var isHistorical = false

                    if stages.isEmpty {
                        if let latest = try await sleepService.fetchLatestSleepStages(withinDays: 7) {
                            stages = latest.stages
                            sleepDate = latest.date
                            isHistorical = true
                        } else {
                            sleepDate = nil
                        }
                    }

                    let output = stages.isEmpty ? nil : sleepScoreUseCase.execute(input: .init(stages: stages))
                    return (.sleep, .sleepResult(output: output, date: sleepDate, isHistorical: isHistorical))
                } catch {
                    print("[Wellness] sleep fetch failed: \(error)")
                    return (.sleep, .fetchError)
                }
            }

            // --- Sleep Weekly ---
            group.addTask {
                guard !Task.isCancelled else { return (.sleepWeekly, .empty) }
                do {
                    let calendar = Calendar.current
                    let today = Date()

                    let dailyData = try await withThrowingTaskGroup(of: DailySleep?.self) { inner in
                        for dayOffset in 0..<7 {
                            inner.addTask { [sleepService] in
                                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
                                let stages = try await sleepService.fetchSleepStages(for: date)
                                let totalMinutes = stages.filter { $0.stage != .awake }.map(\.duration).reduce(0, +) / 60.0
                                return DailySleep(date: date, totalMinutes: totalMinutes)
                            }
                        }
                        var collected: [DailySleep] = []
                        for try await item in inner {
                            if let item { collected.append(item) }
                        }
                        return collected
                    }
                    return (.sleepWeekly, .sleepWeekly(dailyData.sorted { $0.date < $1.date }))
                } catch {
                    print("[Wellness] sleepWeekly fetch failed: \(error)")
                    return (.sleepWeekly, .fetchError)
                }
            }

            // --- Condition (HRV + RHR) ---
            group.addTask {
                guard !Task.isCancelled else { return (.condition, .empty) }
                do {
                    let hrvSamples = try await hrvService.fetchHRVSamples(days: 14)
                    let latestRHRSample = try await hrvService.fetchLatestRestingHeartRate(withinDays: 1)
                    let todayRHR: Double? = latestRHRSample?.value
                    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                    let yesterdayRHR = try await hrvService.fetchRestingHeartRate(for: yesterday)

                    let output = conditionScoreUseCase.execute(input: .init(
                        hrvSamples: hrvSamples,
                        todayRHR: todayRHR,
                        yesterdayRHR: yesterdayRHR
                    ))

                    // Extract latest HRV/RHR raw values for individual cards (Correction #22: range validation)
                    let latestHRV: VitalSample? = hrvSamples.first.flatMap { sample in
                        sample.value > 0 && sample.value <= 500 ? VitalSample(value: sample.value, date: sample.date) : nil
                    }
                    let latestRHRVital: VitalSample? = latestRHRSample.flatMap { sample in
                        sample.value >= 20 && sample.value <= 300 ? VitalSample(value: sample.value, date: sample.date) : nil
                    }

                    return (.condition, .conditionResult(score: output.score, latestHRV: latestHRV, latestRHR: latestRHRVital))
                } catch {
                    print("[Wellness] condition fetch failed: \(error)")
                    return (.condition, .fetchError)
                }
            }

            // --- HRV Weekly (sparkline) ---
            group.addTask {
                guard !Task.isCancelled else { return (.hrvWeekly, .empty) }
                do {
                    let calendar = Calendar.current
                    let end = Date()
                    let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
                    let history = try await hrvService.fetchHRVCollection(
                        start: start, end: end, interval: DateComponents(day: 1)
                    )
                    return (.hrvWeekly, .hrvWeeklyResult(history.map { VitalSample(value: $0.average, date: $0.date) }))
                } catch {
                    print("[Wellness] hrvWeekly fetch failed: \(error)")
                    return (.hrvWeekly, .fetchError)
                }
            }

            // --- RHR Weekly (sparkline) ---
            group.addTask {
                guard !Task.isCancelled else { return (.rhrWeekly, .empty) }
                do {
                    let calendar = Calendar.current
                    let end = Date()
                    let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
                    let history = try await hrvService.fetchRHRCollection(
                        start: start, end: end, interval: DateComponents(day: 1)
                    )
                    return (.rhrWeekly, .rhrWeeklyResult(history.map { VitalSample(value: $0.average, date: $0.date) }))
                } catch {
                    print("[Wellness] rhrWeekly fetch failed: \(error)")
                    return (.rhrWeekly, .fetchError)
                }
            }

            // --- Weight ---
            group.addTask {
                guard !Task.isCancelled else { return (.weight, .empty) }
                do {
                    if let w = try await bodyService.fetchLatestWeight(withinDays: 30) {
                        return (.weight, .vitalSample(VitalSample(value: w.value, date: w.date)))
                    }
                    return (.weight, .empty)
                } catch {
                    print("[Wellness] weight fetch failed: \(error)")
                    return (.weight, .fetchError)
                }
            }

            // --- Weight History (sparkline) ---
            group.addTask {
                guard !Task.isCancelled else { return (.weightHistory, .empty) }
                do {
                    let history = try await bodyService.fetchWeight(days: 7)
                    return (.weightHistory, .weightHistoryResult(history))
                } catch {
                    print("[Wellness] weightHistory fetch failed: \(error)")
                    return (.weightHistory, .fetchError)
                }
            }

            // --- BMI ---
            group.addTask {
                guard !Task.isCancelled else { return (.bmi, .empty) }
                do {
                    if let b = try await bodyService.fetchLatestBMI(withinDays: 30) {
                        return (.bmi, .vitalSample(VitalSample(value: b.value, date: b.date)))
                    }
                    return (.bmi, .empty)
                } catch {
                    print("[Wellness] bmi fetch failed: \(error)")
                    return (.bmi, .fetchError)
                }
            }

            // --- Body Fat ---
            group.addTask {
                guard !Task.isCancelled else { return (.bodyFat, .empty) }
                do {
                    let bfHistory = try await bodyService.fetchBodyFat(days: 7)
                    if let latest = bfHistory.last {
                        return (.bodyFat, .vitalSample(VitalSample(value: latest.value, date: latest.date)))
                    }
                    return (.bodyFat, .empty)
                } catch {
                    print("[Wellness] bodyFat fetch failed: \(error)")
                    return (.bodyFat, .fetchError)
                }
            }

            // --- Body Fat History (sparkline) ---
            group.addTask {
                guard !Task.isCancelled else { return (.bodyFatHistory, .empty) }
                do {
                    let history = try await bodyService.fetchBodyFat(days: 30)
                    return (.bodyFatHistory, .bodyCompositionHistory(history))
                } catch {
                    print("[Wellness] bodyFatHistory fetch failed: \(error)")
                    return (.bodyFatHistory, .fetchError)
                }
            }

            // --- Lean Body Mass ---
            group.addTask {
                guard !Task.isCancelled else { return (.leanBodyMass, .empty) }
                do {
                    if let lbm = try await bodyService.fetchLatestLeanBodyMass(withinDays: 30) {
                        return (.leanBodyMass, .vitalSample(VitalSample(value: lbm.value, date: lbm.date)))
                    }
                    return (.leanBodyMass, .empty)
                } catch {
                    print("[Wellness] leanBodyMass fetch failed: \(error)")
                    return (.leanBodyMass, .fetchError)
                }
            }

            // --- Heart Rate (general) ---
            group.addTask {
                guard !Task.isCancelled else { return (.heartRate, .empty) }
                do {
                    let sample = try await heartRateService.fetchLatestHeartRate(withinDays: 1)
                    return (.heartRate, .vitalSample(sample))
                } catch {
                    print("[Wellness] heartRate fetch failed: \(error)")
                    return (.heartRate, .fetchError)
                }
            }

            // --- Heart Rate History (sparkline) ---
            group.addTask {
                guard !Task.isCancelled else { return (.heartRateHistory, .empty) }
                do {
                    let history = try await heartRateService.fetchHeartRateHistory(days: 7)
                    return (.heartRateHistory, .vitalHistory(history))
                } catch {
                    print("[Wellness] heartRateHistory fetch failed: \(error)")
                    return (.heartRateHistory, .fetchError)
                }
            }

            // --- SpO2 (value is decimal fraction, e.g. 0.98 = 98%) ---
            group.addTask {
                guard !Task.isCancelled else { return (.spo2, .empty) }
                do {
                    let sample = try await vitalsService.fetchLatestSpO2(withinDays: 7)
                    return (.spo2, .vitalSample(sample))
                } catch {
                    print("[Wellness] spo2 fetch failed: \(error)")
                    return (.spo2, .fetchError)
                }
            }

            // --- SpO2 History ---
            group.addTask {
                guard !Task.isCancelled else { return (.spo2History, .empty) }
                do {
                    let history = try await vitalsService.fetchSpO2Collection(days: 7)
                    return (.spo2History, .vitalHistory(history))
                } catch {
                    print("[Wellness] spo2History fetch failed: \(error)")
                    return (.spo2History, .fetchError)
                }
            }

            // --- Respiratory Rate ---
            group.addTask {
                guard !Task.isCancelled else { return (.respRate, .empty) }
                do {
                    let sample = try await vitalsService.fetchLatestRespiratoryRate(withinDays: 7)
                    return (.respRate, .vitalSample(sample))
                } catch {
                    print("[Wellness] respRate fetch failed: \(error)")
                    return (.respRate, .fetchError)
                }
            }

            // --- Respiratory Rate History ---
            group.addTask {
                guard !Task.isCancelled else { return (.respRateHistory, .empty) }
                do {
                    let history = try await vitalsService.fetchRespiratoryRateCollection(days: 7)
                    return (.respRateHistory, .vitalHistory(history))
                } catch {
                    print("[Wellness] respRateHistory fetch failed: \(error)")
                    return (.respRateHistory, .fetchError)
                }
            }

            // --- VO2 Max ---
            group.addTask {
                guard !Task.isCancelled else { return (.vo2Max, .empty) }
                do {
                    let sample = try await vitalsService.fetchLatestVO2Max(withinDays: 180)
                    return (.vo2Max, .vitalSample(sample))
                } catch {
                    print("[Wellness] vo2Max fetch failed: \(error)")
                    return (.vo2Max, .fetchError)
                }
            }

            // --- VO2 Max History ---
            group.addTask {
                guard !Task.isCancelled else { return (.vo2MaxHistory, .empty) }
                do {
                    let history = try await vitalsService.fetchVO2MaxHistory(days: 90)
                    return (.vo2MaxHistory, .vitalHistory(history))
                } catch {
                    print("[Wellness] vo2MaxHistory fetch failed: \(error)")
                    return (.vo2MaxHistory, .fetchError)
                }
            }

            // --- HR Recovery ---
            group.addTask {
                guard !Task.isCancelled else { return (.hrRecovery, .empty) }
                do {
                    let sample = try await vitalsService.fetchLatestHeartRateRecovery(withinDays: 30)
                    return (.hrRecovery, .vitalSample(sample))
                } catch {
                    print("[Wellness] hrRecovery fetch failed: \(error)")
                    return (.hrRecovery, .fetchError)
                }
            }

            // --- HR Recovery History ---
            group.addTask {
                guard !Task.isCancelled else { return (.hrRecoveryHistory, .empty) }
                do {
                    let history = try await vitalsService.fetchHeartRateRecoveryHistory(days: 90)
                    return (.hrRecoveryHistory, .vitalHistory(history))
                } catch {
                    print("[Wellness] hrRecoveryHistory fetch failed: \(error)")
                    return (.hrRecoveryHistory, .fetchError)
                }
            }

            // --- Wrist Temperature ---
            group.addTask {
                guard !Task.isCancelled else { return (.wristTemp, .empty) }
                do {
                    let sample = try await vitalsService.fetchLatestWristTemperature(withinDays: 7)
                    return (.wristTemp, .vitalSample(sample))
                } catch {
                    print("[Wellness] wristTemp fetch failed: \(error)")
                    return (.wristTemp, .fetchError)
                }
            }

            // --- Wrist Temperature Baseline ---
            group.addTask {
                guard !Task.isCancelled else { return (.wristTempBaseline, .empty) }
                do {
                    let baseline = try await vitalsService.fetchWristTemperatureBaseline(days: 14)
                    return (.wristTempBaseline, .baselineResult(baseline))
                } catch {
                    print("[Wellness] wristTempBaseline fetch failed: \(error)")
                    return (.wristTempBaseline, .fetchError)
                }
            }

            // --- Wrist Temperature History ---
            group.addTask {
                guard !Task.isCancelled else { return (.wristTempHistory, .empty) }
                do {
                    let history = try await vitalsService.fetchWristTemperatureCollection(days: 7)
                    return (.wristTempHistory, .vitalHistory(history))
                } catch {
                    print("[Wellness] wristTempHistory fetch failed: \(error)")
                    return (.wristTempHistory, .fetchError)
                }
            }

            // Collect all results
            for await (key, value) in group {
                if case .fetchError = value {
                    results.errorKeys.insert(key)
                    continue
                }
                switch (key, value) {
                case let (.sleep, .sleepResult(output, date, isHistorical)):
                    results.sleep = output
                    results.sleepDate = date
                    results.sleepIsHistorical = isHistorical
                case let (.sleepWeekly, .sleepWeekly(weekly)):
                    results.sleepWeekly = weekly
                case let (.condition, .conditionResult(score, latestHRV, latestRHR)):
                    results.condition = score
                    results.latestHRV = latestHRV
                    results.latestRHR = latestRHR
                case let (.hrvWeekly, .hrvWeeklyResult(history)):
                    results.hrvWeekly = history
                case let (.rhrWeekly, .rhrWeeklyResult(history)):
                    results.rhrWeekly = history
                case let (.weight, .vitalSample(sample)):
                    results.latestWeight = sample
                case let (.weightHistory, .weightHistoryResult(history)):
                    results.weightHistory = history
                case let (.bmi, .vitalSample(sample)):
                    results.latestBMI = sample
                case let (.bodyFat, .vitalSample(sample)):
                    results.latestBodyFat = sample
                case let (.bodyFatHistory, .bodyCompositionHistory(history)):
                    results.bodyFatHistory = history
                case let (.leanBodyMass, .vitalSample(sample)):
                    results.latestLeanBodyMass = sample
                case let (.heartRate, .vitalSample(sample)):
                    results.latestHeartRate = sample
                case let (.heartRateHistory, .vitalHistory(history)):
                    results.heartRateHistory = history
                case let (.spo2, .vitalSample(sample)):
                    results.latestSpO2 = sample
                case let (.spo2History, .vitalHistory(history)):
                    results.spo2History = history
                case let (.respRate, .vitalSample(sample)):
                    results.latestRespRate = sample
                case let (.respRateHistory, .vitalHistory(history)):
                    results.respRateHistory = history
                case let (.vo2Max, .vitalSample(sample)):
                    results.latestVO2Max = sample
                case let (.vo2MaxHistory, .vitalHistory(history)):
                    results.vo2MaxHistory = history
                case let (.hrRecovery, .vitalSample(sample)):
                    results.latestHRRecovery = sample
                case let (.hrRecoveryHistory, .vitalHistory(history)):
                    results.hrRecoveryHistory = history
                case let (.wristTemp, .vitalSample(sample)):
                    results.latestWristTemp = sample
                case let (.wristTempBaseline, .baselineResult(baseline)):
                    results.wristTempBaseline = baseline
                case let (.wristTempHistory, .vitalHistory(history)):
                    results.wristTempHistory = history
                default:
                    break
                }
            }
        }

        // Compute weight week-ago for change calculation
        if let latestWeight = results.latestWeight {
            let weekAgoWeight = results.weightHistory
                .filter { Calendar.current.dateComponents([.day], from: $0.date, to: latestWeight.date).day ?? 0 >= 6 }
                .last
            results.weightWeekAgo = weekAgoWeight?.value
        }

        return results
    }

    // MARK: - Helpers

    private func buildCard(
        category: HealthMetric.Category,
        title: String,
        rawValue: Double,
        formattedValue: String,
        unit: String,
        change: Double?,
        sparkline: [Double],
        date: Date,
        isHistorical: Bool
    ) -> VitalCardData {
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        let isStale = daysSince >= Self.staleDays

        var changeStr: String?
        var changePositive: Bool? // Note: true means numerically positive, not necessarily "good" (e.g. weight increase)
        if let change, !isHistorical { // Correction #24: skip change for historical data
            let absChange = abs(change)
            if absChange >= 0.1 {
                changeStr = String(format: "%@%.1f", change >= 0 ? "+" : "", change)
                changePositive = change > 0
            }
        }

        let metric = HealthMetric(
            id: category.rawValue,
            name: title,
            value: rawValue,
            unit: unit,
            change: isHistorical ? nil : change,
            date: date,
            category: category,
            isHistorical: isHistorical
        )

        return VitalCardData(
            id: category.rawValue,
            category: category,
            section: CardSection.section(for: category),
            title: title,
            value: formattedValue,
            unit: unit,
            change: changeStr,
            changeIsPositive: changePositive,
            sparklineData: sparkline,
            metric: metric,
            lastUpdated: date,
            isStale: isStale
        )
    }

    private func buildBodyTrend(results: FetchResults) -> CalculateWellnessScoreUseCase.BodyTrend? {
        let weightChange: Double?
        if let current = results.latestWeight, let weekAgo = results.weightWeekAgo {
            weightChange = current.value - weekAgo
        } else {
            weightChange = nil
        }

        // bodyFatChange requires weekly history fetch — not yet implemented
        guard weightChange != nil else { return nil }

        return CalculateWellnessScoreUseCase.BodyTrend(
            weightChange: weightChange,
            bodyFatChange: nil
        )
    }

    private static func formatSleepMinutes(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}
