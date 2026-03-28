import Foundation
import HealthKit

protocol BreathingDisturbanceQuerying: Sendable {
    func fetchNightlyDisturbances(days: Int) async throws -> [BreathingDisturbanceSample]
    func fetchLatestDisturbance(withinDays days: Int) async throws -> BreathingDisturbanceSample?
    func analyze(samples: [BreathingDisturbanceSample]) -> BreathingDisturbanceAnalysis
}

struct BreathingDisturbanceQueryService: BreathingDisturbanceQuerying, Sendable {
    private let manager: HealthKitManager

    /// Valid range for breathing disturbances (count/hour).
    private let validRange = 0.0...100.0

    /// Threshold for classifying a night as elevated (disturbances per hour).
    private let elevatedThreshold = 10.0

    init(manager: HealthKitManager = .shared) {
        self.manager = manager
    }

    func fetchNightlyDisturbances(days: Int) async throws -> [BreathingDisturbanceSample] {
        let quantityType = HKQuantityType(.appleSleepingBreathingDisturbances)
        try await manager.ensureNotDenied(for: quantityType)

        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)

        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: quantityType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let results = try await manager.execute(query)

        return results.compactMap { sample -> BreathingDisturbanceSample? in
            let value = sample.quantity.doubleValue(for: .count().unitDivided(by: .hour()))
            guard validRange.contains(value) else { return nil }
            return BreathingDisturbanceSample(
                value: value,
                date: sample.startDate,
                isElevated: value >= elevatedThreshold
            )
        }
    }

    func fetchLatestDisturbance(withinDays days: Int) async throws -> BreathingDisturbanceSample? {
        let samples = try await fetchNightlyDisturbances(days: days)
        return samples.first
    }

    func analyze(samples: [BreathingDisturbanceSample]) -> BreathingDisturbanceAnalysis {
        let average: Double?
        if samples.isEmpty {
            average = nil
        } else {
            let sum = samples.reduce(0.0) { $0 + $1.value }
            average = sum / Double(samples.count)
        }

        let elevatedCount = samples.filter(\.isElevated).count
        let riskLevel: BreathingDisturbanceAnalysis.RiskLevel
        if let avg = average {
            riskLevel = BreathingDisturbanceAnalysis.classifyRisk(average: avg)
        } else {
            riskLevel = .normal
        }

        return BreathingDisturbanceAnalysis(
            samples: samples,
            average: average,
            elevatedNightCount: elevatedCount,
            riskLevel: riskLevel
        )
    }
}
