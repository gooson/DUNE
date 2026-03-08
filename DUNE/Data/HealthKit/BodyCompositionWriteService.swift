import Foundation
import HealthKit

struct BodyCompositionWriteInput: Sendable {
    let date: Date
    let weight: Double?
    let bodyFatPercentage: Double?
    let leanBodyMass: Double?

    func makeSamples() -> [HKQuantitySample] {
        var samples: [HKQuantitySample] = []

        if let weight, weight > 0, weight.isFinite {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.bodyMass),
                quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weight),
                start: date,
                end: date
            ))
        }

        if let bodyFatPercentage,
           bodyFatPercentage >= 0, bodyFatPercentage <= 100,
           bodyFatPercentage.isFinite {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.bodyFatPercentage),
                quantity: HKQuantity(unit: .percent(), doubleValue: bodyFatPercentage / 100),
                start: date,
                end: date
            ))
        }

        if let leanBodyMass, leanBodyMass > 0, leanBodyMass.isFinite {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.leanBodyMass),
                quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: leanBodyMass),
                start: date,
                end: date
            ))
        }

        return samples
    }
}

protocol BodyCompositionWriting: Sendable {
    func save(_ input: BodyCompositionWriteInput) async throws
}

struct BodyCompositionWriteService: BodyCompositionWriting, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager = .shared) {
        self.manager = manager
    }

    func save(_ input: BodyCompositionWriteInput) async throws {
        let samples = input.makeSamples()
        guard !samples.isEmpty else {
            throw HealthKitError.queryFailed("No body composition samples to save")
        }

        try await manager.requestAuthorization()

        let store = await manager.healthStore
        let isAuthorized = samples.allSatisfy { sample in
            store.authorizationStatus(for: sample.sampleType) == .sharingAuthorized
        }
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        for sample in samples {
            do {
                try await store.save(sample)
            } catch {
                AppLogger.healthKit.error("Saving body composition sample failed: \(error.localizedDescription)")
                throw HealthKitError.queryFailed(error.localizedDescription)
            }
        }

        AppLogger.healthKit.info("Saved body composition samples to HealthKit")
    }
}
