import Foundation
import SwiftData

/// Independent, additive entity: deployed ExerciseRecord schema checksums stay unchanged.
@Model
final class WorkoutLocationRecord {
    // CloudKit requires defaults or optional values for every persisted scalar.
    var id: UUID = UUID()
    var localRecordID: UUID?
    var healthKitWorkoutID: String?
    var payloadData: Data?
    var updatedAt: Date = Date()

    var payload: WorkoutLocationPayload? {
        get {
            guard let payloadData, payloadData.count <= 1_000_000 else { return nil }
            // Corrupt or future payloads are unavailable; retain the bytes for recovery.
            guard let decoded = try? JSONDecoder().decode(WorkoutLocationPayload.self, from: payloadData) else { return nil }
            return WorkoutLocationPayload(isIndoor: decoded.isIndoor, route: decoded.route, place: decoded.place)
        }
        set {
            guard let newValue else { payloadData = nil; updatedAt = Date(); return }
            let safe = WorkoutLocationPayload(isIndoor: newValue.isIndoor, route: newValue.route, place: newValue.place)
            do {
                let data = try JSONEncoder().encode(safe)
                guard data.count <= 1_000_000 else { return }
                payloadData = data
                updatedAt = Date()
            } catch {
                // Preserve the previously saved payload if encoding unexpectedly fails.
                assertionFailure("Validated workout location could not be encoded")
            }
        }
    }

    init(localRecordID: UUID? = nil, healthKitWorkoutID: String? = nil, payload: WorkoutLocationPayload) {
        self.localRecordID = localRecordID
        self.healthKitWorkoutID = healthKitWorkoutID
        self.payload = payload
    }
}
