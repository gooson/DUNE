import Foundation
import SwiftData

actor HealthSnapshotMirrorStore: HealthSnapshotMirroring {
    private static let payloadVersion = 1
    private static let maxRecords = 240

    private let modelContainer: ModelContainer
    private let sourceDevice: String

    private var lastPersistedFetchedAt: Date?

    init(
        modelContainer: ModelContainer,
        sourceDevice: String = HealthSnapshotMirrorStore.defaultSourceDevice
    ) {
        self.modelContainer = modelContainer
        self.sourceDevice = sourceDevice
    }

    func persist(snapshot: SharedHealthSnapshot) async {
        guard snapshot.fetchedAt != lastPersistedFetchedAt else { return }

        do {
            try persistOrUpdate(snapshot: snapshot)
            lastPersistedFetchedAt = snapshot.fetchedAt
        } catch {
            AppLogger.data.error("HealthSnapshotMirrorStore persist failed: \(error.localizedDescription)")
        }
    }

    private func persistOrUpdate(snapshot: SharedHealthSnapshot) throws {
        let context = ModelContext(modelContainer)
        let payload = HealthSnapshotMirrorMapper.makePayload(from: snapshot)
        let payloadJSON = try HealthSnapshotMirrorMapper.encode(payload)

        let fetchedAt = snapshot.fetchedAt
        let descriptor = FetchDescriptor<HealthSnapshotMirrorRecord>(
            predicate: #Predicate { record in
                record.fetchedAt == fetchedAt
            }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.syncedAt = Date()
            existing.sourceDevice = sourceDevice
            existing.payloadVersion = Self.payloadVersion
            existing.payloadJSON = payloadJSON
        } else {
            let record = HealthSnapshotMirrorRecord(
                fetchedAt: fetchedAt,
                syncedAt: Date(),
                sourceDevice: sourceDevice,
                payloadVersion: Self.payloadVersion,
                payloadJSON: payloadJSON
            )
            context.insert(record)
        }

        try trimOldRecordsIfNeeded(in: context)
        try context.save()
    }

    private func trimOldRecordsIfNeeded(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<HealthSnapshotMirrorRecord>(
            sortBy: [SortDescriptor(\HealthSnapshotMirrorRecord.fetchedAt, order: .reverse)]
        )

        let records = try context.fetch(descriptor)
        guard records.count > Self.maxRecords else { return }

        for record in records.dropFirst(Self.maxRecords) {
            context.delete(record)
        }
    }

    private static var defaultSourceDevice: String {
#if os(watchOS)
        "watchOS"
#elseif os(iOS)
        "iOS"
#elseif os(macOS)
        "macOS"
#else
        "unknown"
#endif
    }
}
