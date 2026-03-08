import Foundation
import HealthKit

enum BodyCompositionSampleKind: String, CaseIterable, Sendable {
    case weight
    case bodyFatPercentage = "body-fat-percentage"
    case leanBodyMass = "lean-body-mass"

    var quantityType: HKQuantityType {
        switch self {
        case .weight:
            HKQuantityType(.bodyMass)
        case .bodyFatPercentage:
            HKQuantityType(.bodyFatPercentage)
        case .leanBodyMass:
            HKQuantityType(.leanBodyMass)
        }
    }
}

struct BodyCompositionWriteInput: Sendable {
    static let syncIdentifierPrefix = "com.dune.body-composition"

    let date: Date
    let weight: Double?
    let bodyFatPercentage: Double?
    let leanBodyMass: Double?

    init(
        date: Date,
        weight: Double?,
        bodyFatPercentage: Double?,
        leanBodyMass: Double?
    ) {
        self.date = date
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
        self.leanBodyMass = leanBodyMass
    }

#if os(iOS)
    init(record: BodyCompositionRecord) {
        self.init(
            date: record.date,
            weight: record.weight,
            bodyFatPercentage: record.bodyFatPercentage,
            leanBodyMass: record.muscleMass
        )
    }
#endif

    var activeSampleKinds: Set<BodyCompositionSampleKind> {
        Set(BodyCompositionSampleKind.allCases.filter { quantity(for: $0) != nil })
    }

    func makeSamples(
        recordID: UUID,
        syncVersion: Int64 = Self.makeSyncVersion()
    ) -> [HKQuantitySample] {
        BodyCompositionSampleKind.allCases.compactMap { kind in
            guard let quantity = quantity(for: kind) else { return nil }
            return HKQuantitySample(
                type: kind.quantityType,
                quantity: quantity,
                start: date,
                end: date,
                metadata: [
                    HKMetadataKeySyncIdentifier: Self.syncIdentifier(recordID: recordID, kind: kind),
                    HKMetadataKeySyncVersion: NSNumber(value: syncVersion),
                    HKMetadataKeyExternalUUID: recordID.uuidString.lowercased(),
                ]
            )
        }
    }

    static func syncIdentifier(recordID: UUID, kind: BodyCompositionSampleKind) -> String {
        "\(syncIdentifierPrefix).\(recordID.uuidString.lowercased()).\(kind.rawValue)"
    }

    static func makeSyncVersion(now: Date = Date()) -> Int64 {
        Int64(now.timeIntervalSince1970 * 1_000_000)
    }

    private func quantity(for kind: BodyCompositionSampleKind) -> HKQuantity? {
        switch kind {
        case .weight:
            guard let weight, weight > 0, weight.isFinite else { return nil }
            return HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weight)
        case .bodyFatPercentage:
            guard let bodyFatPercentage,
                  bodyFatPercentage >= 0, bodyFatPercentage <= 100,
                  bodyFatPercentage.isFinite else { return nil }
            return HKQuantity(unit: .percent(), doubleValue: bodyFatPercentage / 100)
        case .leanBodyMass:
            guard let leanBodyMass, leanBodyMass > 0, leanBodyMass.isFinite else { return nil }
            return HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: leanBodyMass)
        }
    }
}

protocol BodyCompositionWriting: Sendable {
    func save(recordID: UUID, input: BodyCompositionWriteInput) async throws
    func update(recordID: UUID, previousInput: BodyCompositionWriteInput, input: BodyCompositionWriteInput) async throws
    func delete(recordID: UUID, input: BodyCompositionWriteInput) async throws
}

enum BodyCompositionWriteError: Error {
    case emptyMeasurements
    case notAuthorized
    case saveFailed
    case deleteFailed
}

struct BodyCompositionWriteService: BodyCompositionWriting, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager = .shared) {
        self.manager = manager
    }

    func save(recordID: UUID, input: BodyCompositionWriteInput) async throws {
        try await sync(recordID: recordID, previousInput: nil, currentInput: input)
    }

    func update(recordID: UUID, previousInput: BodyCompositionWriteInput, input: BodyCompositionWriteInput) async throws {
        try await sync(recordID: recordID, previousInput: previousInput, currentInput: input)
    }

    func delete(recordID: UUID, input: BodyCompositionWriteInput) async throws {
        try await sync(recordID: recordID, previousInput: input, currentInput: nil)
    }

    private func sync(
        recordID: UUID,
        previousInput: BodyCompositionWriteInput?,
        currentInput: BodyCompositionWriteInput?
    ) async throws {
        let previousKinds = previousInput?.activeSampleKinds ?? []
        let currentKinds = currentInput?.activeSampleKinds ?? []
        guard !previousKinds.isEmpty || !currentKinds.isEmpty else {
            throw BodyCompositionWriteError.emptyMeasurements
        }

        try await manager.requestBodyCompositionWriteAuthorization()

        let store = await manager.healthStore
        let requiredTypes = previousKinds.union(currentKinds).map(\.quantityType)
        let isAuthorized = requiredTypes.allSatisfy { type in
            store.authorizationStatus(for: type) == .sharingAuthorized
        }
        guard isAuthorized else {
            throw BodyCompositionWriteError.notAuthorized
        }

        if let currentInput {
            let samples = currentInput.makeSamples(recordID: recordID)
            if !samples.isEmpty {
                do {
                    try await store.save(samples)
                } catch {
                    AppLogger.healthKit.error("Saving body composition samples failed: \(error.localizedDescription)")
                    throw BodyCompositionWriteError.saveFailed
                }
            }
        }

        let removedKinds = previousKinds.subtracting(currentKinds)
        if !removedKinds.isEmpty {
            do {
                try await deleteSamples(recordID: recordID, kinds: removedKinds, store: store)
            } catch {
                AppLogger.healthKit.error("Deleting body composition samples failed: \(error.localizedDescription)")
                throw BodyCompositionWriteError.deleteFailed
            }
        }

        AppLogger.healthKit.info("Synced body composition samples to HealthKit")
    }

    private func deleteSamples(
        recordID: UUID,
        kinds: Set<BodyCompositionSampleKind>,
        store: HKHealthStore
    ) async throws {
        for kind in kinds {
            let predicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeySyncIdentifier,
                allowedValues: [BodyCompositionWriteInput.syncIdentifier(recordID: recordID, kind: kind)]
            )
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                store.deleteObjects(of: kind.quantityType, predicate: predicate) { success, _, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard success else {
                        continuation.resume(throwing: BodyCompositionWriteError.deleteFailed)
                        return
                    }
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
