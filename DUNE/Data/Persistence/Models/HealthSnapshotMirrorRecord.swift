import Foundation
import SwiftData

/// Cloud-synced snapshot payload generated from SharedHealthSnapshot.
/// Used as a cross-device mirror for platforms without direct HealthKit access.
@Model
final class HealthSnapshotMirrorRecord {
    var id: UUID = UUID()
    var fetchedAt: Date = Date()
    var syncedAt: Date = Date()
    var sourceDevice: String = "iOS"
    var payloadVersion: Int = 1
    var payloadJSON: String = "{}"

    init(
        fetchedAt: Date = Date(),
        syncedAt: Date = Date(),
        sourceDevice: String = "iOS",
        payloadVersion: Int = 1,
        payloadJSON: String = "{}"
    ) {
        self.id = UUID()
        self.fetchedAt = fetchedAt
        self.syncedAt = syncedAt
        self.sourceDevice = sourceDevice
        self.payloadVersion = payloadVersion
        self.payloadJSON = payloadJSON
    }
}
