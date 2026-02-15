import HealthKit

struct SleepQueryService: Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager = .shared) {
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
        // Sort by start time for sweep-line approach
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var result: [HKCategorySample] = []

        for sample in sorted {
            let hasOverlap = result.contains { existing in
                existing.startDate < sample.endDate && sample.startDate < existing.endDate
            }
            if !hasOverlap {
                result.append(sample)
            } else if isWatchSource(sample) {
                // Replace overlapping non-Watch samples with Watch sample
                result.removeAll { existing in
                    !isWatchSource(existing)
                        && existing.startDate < sample.endDate
                        && sample.startDate < existing.endDate
                }
                result.append(sample)
            }
        }
        return result.sorted { $0.startDate < $1.startDate }
    }

    private func isWatchSource(_ sample: HKSample) -> Bool {
        let bundleID = sample.sourceRevision.source.bundleIdentifier
        return bundleID.contains("watch") || bundleID.contains("Watch")
    }
}
