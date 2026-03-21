import HealthKit

protocol SleepQuerying: Sendable {
    func fetchSleepStages(for date: Date) async throws -> [SleepStage]
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)?
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])]
    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary?
}

struct SleepQueryService: SleepQuerying, Sendable {
    private let manager: HealthKitManager
    private static let sleepQueryStartOffsetHours = -12
    private static let primarySleepWindowEndOffsetHours = 12
    private static let extendedSleepWindowEndOffsetHours = 18
    private static let lateWakeContinuationGap: TimeInterval = 90 * 60

    init(manager: HealthKitManager) {
        self.manager = manager
    }

    func fetchSleepStages(for date: Date) async throws -> [SleepStage] {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.sleepStages(for: date)
        }
        guard manager.isAvailable else { return [] }
        try await manager.ensureNotDenied(for: HKCategoryType(.sleepAnalysis))
        let calendar = Calendar.current
        guard let queryWindow = Self.sleepQueryWindow(for: date, calendar: calendar) else {
            return [] 
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: queryWindow.start,
            end: queryWindow.extendedEnd,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )

        let samples = try await manager.execute(descriptor)

        // Deduplicate with time-range-aware cross-source handling:
        // Watch data is preferred, but non-Watch fills gaps where Watch has no coverage.
        let stages = deduplicateAndConvert(samples)
        return Self.trimLateWakeContinuation(
            stages,
            primaryWindowEnd: queryWindow.primaryEnd
        )
    }

    // Keep the existing noon-anchored sleep day, but query a few more hours so
    // late wake stages after 12:00 are still available for trimming.
    static func sleepQueryWindow(
        for date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, primaryEnd: Date, extendedEnd: Date)? {
        let startOfDay = calendar.startOfDay(for: date)
        guard
            let start = calendar.date(
                byAdding: .hour,
                value: Self.sleepQueryStartOffsetHours,
                to: startOfDay
            ),
            let primaryEnd = calendar.date(
                byAdding: .hour,
                value: Self.primarySleepWindowEndOffsetHours,
                to: startOfDay
            ),
            let extendedEnd = calendar.date(
                byAdding: .hour,
                value: Self.extendedSleepWindowEndOffsetHours,
                to: startOfDay
            )
        else {
            return nil
        }

        return (start: start, primaryEnd: primaryEnd, extendedEnd: extendedEnd)
    }

    // Only extend beyond the noon anchor when the later stages are still part of
    // the same contiguous sleep session. This avoids pulling in afternoon naps.
    static func trimLateWakeContinuation(
        _ stages: [SleepStage],
        primaryWindowEnd: Date,
        maxGap: TimeInterval = SleepQueryService.lateWakeContinuationGap
    ) -> [SleepStage] {
        guard !stages.isEmpty else { return [] }
        guard let lastPrimaryIndex = stages.lastIndex(where: { $0.startDate < primaryWindowEnd }) else {
            return stages
        }

        var endIndex = lastPrimaryIndex
        var previousEnd = stages[lastPrimaryIndex].endDate

        for index in stages.index(after: lastPrimaryIndex)..<stages.endIndex {
            let nextStage = stages[index]
            let gap = nextStage.startDate.timeIntervalSince(previousEnd)
            guard gap <= maxGap else { break }
            endIndex = index
            previousEnd = nextStage.endDate
        }

        return Array(stages[...endIndex])
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

    // MARK: - Time-range-aware dedup

    /// Deduplicates sleep samples and converts to SleepStage in one pass.
    /// Watch data takes priority, but non-Watch data fills time gaps where Watch has no coverage.
    /// This prevents data loss when the Watch only covers part of the sleep session.
    private func deduplicateAndConvert(_ samples: [HKCategorySample]) -> [SleepStage] {
        guard !samples.isEmpty else { return [] }

        // 1. Partition by Watch vs non-Watch
        var watchSamples: [HKCategorySample] = []
        var nonWatchSamples: [HKCategorySample] = []
        for sample in samples {
            if isWatchSource(sample) {
                watchSamples.append(sample)
            } else {
                nonWatchSamples.append(sample)
            }
        }

        // 2. Same-source dedup within each group
        let dedupedWatch = deduplicateSameSourceGroup(watchSamples)
        let dedupedNonWatch = deduplicateSameSourceGroup(nonWatchSamples)

        // 3. Convert Watch samples → SleepStage
        var stages: [SleepStage] = dedupedWatch.compactMap { sample in
            guard let stage = mapSleepCategory(sample.value) else { return nil }
            return SleepStage(
                stage: stage,
                duration: sample.endDate.timeIntervalSince(sample.startDate),
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        }

        // 4. Build merged Watch coverage intervals
        let watchCoverage = Self.mergedIntervals(stages.map { ($0.startDate, $0.endDate) })

        // 5. Non-Watch: trim against Watch coverage, keep remainder
        for sample in dedupedNonWatch {
            guard let stage = mapSleepCategory(sample.value) else { continue }
            let trimmed = Self.subtractIntervals(
                from: (sample.startDate, sample.endDate),
                subtracting: watchCoverage
            )
            for (start, end) in trimmed {
                let duration = end.timeIntervalSince(start)
                guard duration > 0 else { continue }
                stages.append(SleepStage(
                    stage: stage,
                    duration: duration,
                    startDate: start,
                    endDate: end
                ))
            }
        }

        return stages.sorted { $0.startDate < $1.startDate }
    }

    /// Dedup within a single priority group (all-Watch or all-non-Watch).
    /// Same-source overlaps are kept (stage transitions). Cross-source uses longer-duration wins.
    private func deduplicateSameSourceGroup(_ samples: [HKCategorySample]) -> [HKCategorySample] {
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var result: [HKCategorySample] = []

        for sample in sorted {
            var overlapIndices: [Int] = []
            // Full scan instead of break-early sweep to handle unsorted result after mutations
            for i in 0..<result.count {
                let existing = result[i]
                if existing.startDate < sample.endDate && sample.startDate < existing.endDate {
                    overlapIndices.append(i)
                }
            }

            if overlapIndices.isEmpty {
                result.append(sample)
                continue
            }

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

            // Cross-source within same priority group: keep longer duration
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
        return result
    }

    // MARK: - Interval helpers

    /// Merges overlapping time intervals into non-overlapping sorted intervals.
    static func mergedIntervals(_ intervals: [(Date, Date)]) -> [(Date, Date)] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.0 < $1.0 }
        var merged: [(Date, Date)] = [sorted[0]]
        for interval in sorted.dropFirst() {
            if interval.0 <= merged[merged.count - 1].1 {
                // Overlaps or adjacent — extend
                merged[merged.count - 1].1 = max(merged[merged.count - 1].1, interval.1)
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    /// Subtracts sorted non-overlapping intervals from a single interval.
    /// Returns the remaining portions of `from` not covered by `subtracting`.
    static func subtractIntervals(
        from interval: (Date, Date),
        subtracting: [(Date, Date)]
    ) -> [(Date, Date)] {
        guard !subtracting.isEmpty else { return [interval] }
        var result: [(Date, Date)] = []
        var currentStart = interval.0

        for sub in subtracting {
            // Skip subtraction intervals that end before our current position
            guard sub.1 > currentStart else { continue }
            // Stop if subtraction interval starts after our interval ends
            guard sub.0 < interval.1 else { break }

            // Keep the gap before this subtraction interval
            if sub.0 > currentStart {
                result.append((currentStart, min(sub.0, interval.1)))
            }
            currentStart = max(currentStart, sub.1)
        }

        // Keep the remainder after the last subtraction interval
        if currentStart < interval.1 {
            result.append((currentStart, interval.1))
        }
        return result
    }

    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? {
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.latestSleepStages(withinDays: days)
        }
        guard manager.isAvailable else { return nil }
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
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            return mockData.sleepDailyDurations(start: start, end: end).map {
                (date: $0.date, totalMinutes: $0.totalMinutes, stageBreakdown: $0.stageBreakdown)
            }
        }
        guard manager.isAvailable else { return [] }
        let calendar = Calendar.current
        let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 7

        return try await withThrowingTaskGroup(
            of: (Date, Double, [SleepStage.Stage: Double])?.self
        ) { group in
            for dayOffset in 0...dayCount {
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
        if let mockData = SimulatorAdvancedMockDataProvider.current() {
            let stages = mockData.sleepStages(for: date)
            return sleepSummary(from: stages, date: date)
        }
        guard manager.isAvailable else { return nil }
        let stages = try await fetchSleepStages(for: date)
        return sleepSummary(from: stages, date: date)
    }

    private func sleepSummary(from stages: [SleepStage], date: Date) -> SleepSummary? {
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
        Self.isWatchSource(
            productType: sample.sourceRevision.productType,
            bundleIdentifier: sample.sourceRevision.source.bundleIdentifier
        )
    }

    static func isWatchSource(productType: String?, bundleIdentifier: String) -> Bool {
        // 1. Product type check: most reliable (e.g., "Watch6,18", "Watch7,1")
        if let productType, productType.hasPrefix("Watch") {
            return true
        }
        // 2. Bundle ID fallback (e.g., com.apple.NanoHealthApp, watchkit child bundles)
        return bundleIdentifier.localizedCaseInsensitiveContains("watch")
            || bundleIdentifier.localizedCaseInsensitiveContains("nano")
    }
}
