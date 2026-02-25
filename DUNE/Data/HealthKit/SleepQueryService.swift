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

        // Deduplicate: prefer Apple Watch source over iPhone; same-source overlaps kept
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
        case .asleepUnspecified:
            return .unspecified
        case .inBed:
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
                continue
            }

            // Same source overlap: keep both unless unspecified duplicates specific stages
            let sampleSource = sample.sourceRevision.source.bundleIdentifier
            let allSameSource = overlapIndices.allSatisfy {
                result[$0].sourceRevision.source.bundleIdentifier == sampleSource
            }
            if allSameSource {
                // Skip broad unspecified when specific stages already cover the period
                let category = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                if category == .asleepUnspecified {
                    let hasSpecificOverlap = overlapIndices.contains { i in
                        let existing = HKCategoryValueSleepAnalysis(rawValue: result[i].value)
                        return existing != .asleepUnspecified && existing != .inBed
                    }
                    if hasSpecificOverlap { continue }
                }
                result.append(sample)
                continue
            }

            // Cross-source overlap: prefer Watch over non-Watch
            let sampleIsWatch = isWatchSource(sample)
            let anyOverlapIsWatch = overlapIndices.contains { isWatchSource(result[$0]) }

            if sampleIsWatch && !anyOverlapIsWatch {
                // Watch replaces non-Watch
                for i in overlapIndices.sorted(by: >) {
                    result.remove(at: i)
                }
                result.append(sample)
            } else if !sampleIsWatch && anyOverlapIsWatch {
                // Non-Watch overlaps Watch → skip
                continue
            } else {
                // Same priority, different source: keep longer duration
                let sampleDuration = sample.endDate.timeIntervalSince(sample.startDate)
                let maxExistingDuration = overlapIndices.map {
                    result[$0].endDate.timeIntervalSince(result[$0].startDate)
                }.max() ?? 0
                if sampleDuration > maxExistingDuration {
                    for i in overlapIndices.sorted(by: >) {
                        result.remove(at: i)
                    }
                    result.append(sample)
                }
            }
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
        // 1. Product type check: most reliable (e.g., "Watch6,18", "Watch7,1")
        if let productType = sample.sourceRevision.productType,
           productType.hasPrefix("Watch") {
            return true
        }
        // 2. Bundle ID fallback (e.g., com.apple.NanoHealthApp)
        let bundleID = sample.sourceRevision.source.bundleIdentifier
        return bundleID.localizedCaseInsensitiveContains("watch")
    }
}
