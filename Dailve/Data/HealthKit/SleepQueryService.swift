import HealthKit

protocol SleepQuerying: Sendable {
    func fetchSleepStages(for date: Date) async throws -> [SleepStage]
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)?
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])]
    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary?
}

struct SleepQueryService: SleepQuerying, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager) {
        self.manager = manager
    }

    func fetchSleepStages(for date: Date) async throws -> [SleepStage] {
        try await manager.ensureNotDenied(for: HKCategoryType(.sleepAnalysis))
        let calendar = Calendar.current
        // Sleep data typically starts the evening before
        guard let sleepWindowStart = calendar.date(byAdding: .hour, value: -12, to: calendar.startOfDay(for: date)),
              let sleepWindowEnd = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: date)) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: sleepWindowStart,
            end: sleepWindowEnd,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )

        let samples = try await manager.execute(descriptor)

        // Deduplicate: prefer Apple Watch source over iPhone
        let deduped = deduplicateSamples(samples)

        return deduped.compactMap { sample in
            guard let stage = mapSleepCategory(sample.value) else { return nil }
            return SleepStage(
                stage: stage,
                duration: sample.endDate.timeIntervalSince(sample.startDate),
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        }
    }

    private func mapSleepCategory(_ value: Int) -> SleepStage.Stage? {
        guard let category = HKCategoryValueSleepAnalysis(rawValue: value) else {
            return nil
        }
        switch category {
        case .awake:
            return .awake
        case .asleepCore:
            return .core
        case .asleepDeep:
            return .deep
        case .asleepREM:
            return .rem
        case .inBed, .asleepUnspecified:
            return nil
        @unknown default:
            return nil
        }
    }

    private func deduplicateSamples(_ samples: [HKCategorySample]) -> [HKCategorySample] {
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var result: [HKCategorySample] = []

        for sample in sorted {
            // Sweep-line: only check trailing entries that could overlap (already sorted by startDate)
            var overlapIndices: [Int] = []
            for i in stride(from: result.count - 1, through: 0, by: -1) {
                let existing = result[i]
                guard existing.endDate > sample.startDate else { break }
                if existing.startDate < sample.endDate {
                    overlapIndices.append(i)
                }
            }

            if overlapIndices.isEmpty {
                result.append(sample)
            } else if isWatchSource(sample) {
                // Replace overlapping non-Watch samples with Watch sample
                for i in overlapIndices.sorted(by: >) where !isWatchSource(result[i]) {
                    result.remove(at: i)
                }
                result.append(sample)
            }
            // else: non-Watch sample overlaps existing → skip
        }
        return result
    }

    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? {
        let calendar = Calendar.current
        let today = Date()
        for dayOffset in 0...days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let stages = try await fetchSleepStages(for: date)
            let sleepStages = stages.filter { $0.stage != .awake }
            if !sleepStages.isEmpty {
                return (stages: stages, date: date)
            }
        }
        return nil
    }

    func fetchDailySleepDurations(
        start: Date,
        end: Date
    ) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] {
        let calendar = Calendar.current
        let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 7

        return try await withThrowingTaskGroup(
            of: (Date, Double, [SleepStage.Stage: Double])?.self
        ) { group in
            for dayOffset in 0..<dayCount {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: start) else { continue }
                group.addTask { [self] in
                    let stages = try await self.fetchSleepStages(for: date)
                    let sleepStages = stages.filter { $0.stage != .awake }
                    guard !sleepStages.isEmpty else { return nil }

                    let totalMinutes = sleepStages.reduce(0.0) { $0 + $1.duration } / 60.0
                    var breakdown: [SleepStage.Stage: Double] = [:]
                    for stage in sleepStages {
                        breakdown[stage.stage, default: 0] += stage.duration / 60.0
                    }
                    return (date, totalMinutes, breakdown)
                }
            }

            var results: [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] = []
            for try await result in group {
                if let result {
                    results.append((date: result.0, totalMinutes: result.1, stageBreakdown: result.2))
                }
            }
            return results.sorted { $0.date < $1.date }
        }
    }

    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? {
        let stages = try await fetchSleepStages(for: date)
        let sleepStages = stages.filter { $0.stage != .awake }
        guard !sleepStages.isEmpty else { return nil }

        let totalSeconds = sleepStages.reduce(0.0) { $0 + $1.duration }
        guard totalSeconds > 0 else { return nil }

        let totalMinutes = totalSeconds / 60.0
        let deepSeconds = sleepStages.filter { $0.stage == .deep }.reduce(0.0) { $0 + $1.duration }
        let remSeconds = sleepStages.filter { $0.stage == .rem }.reduce(0.0) { $0 + $1.duration }

        let deepRatio = Swift.min(deepSeconds / totalSeconds, 1.0)
        let remRatio = Swift.min(remSeconds / totalSeconds, 1.0)

        return SleepSummary(
            totalSleepMinutes: totalMinutes,
            deepSleepRatio: deepRatio,
            remSleepRatio: remRatio,
            date: date
        )
    }

    private func isWatchSource(_ sample: HKSample) -> Bool {
        let bundleID = sample.sourceRevision.source.bundleIdentifier
        return bundleID.contains("watch") || bundleID.contains("Watch")
    }
}
