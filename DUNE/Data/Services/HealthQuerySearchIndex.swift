import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Opt-in, protected, replace-only index. Exact query aggregation never depends on Spotlight.
@MainActor
final class HealthQuerySearchIndex {
    static let shared = HealthQuerySearchIndex()
    private let index: CSSearchableIndex
    private var revision = 0
    private var pending: Task<Void, Error>?

    init(index: CSSearchableIndex = CSSearchableIndex(
        name: "DUNE.HealthQuery.Private", protectionClass: .complete)) {
        self.index = index
    }

    /// Serializes replacement and deletion so disabling cannot race with an older insertion.
    func replace(records: [HealthQueryWorkoutSnapshot], enabled: Bool) async throws {
        revision += 1
        let currentRevision = revision
        let previous = pending
        let index = index
        let items = enabled ? Self.items(records) : []
        let operation = Task { @MainActor [weak self] in
            // A failed earlier write must not prevent a later privacy deletion.
            if let previous { _ = await previous.result }
            try await index.deleteAllSearchableItems()
            guard self?.revision == currentRevision, enabled,
                  UserDefaults.standard.bool(forKey: HealthQueryPreferences.semanticSearchEnabledKey) else { return }
            try Task.checkCancellation()
            try await index.indexSearchableItems(items)
        }
        pending = operation
        try await operation.value
        if revision == currentRevision { pending = nil }
    }

    func removeAll() async throws {
        try await replace(records: [], enabled: false)
    }

    static func items(_ records: [HealthQueryWorkoutSnapshot]) -> [CSSearchableItem] {
        var seen: Set<String> = []
        return records.prefix(200).compactMap { record in
            guard record.source == .app, !record.memo.isEmpty, seen.insert(record.id).inserted else { return nil }
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = String(record.name.prefix(100))
            attributes.contentDescription = String(record.memo.prefix(500))
            attributes.contentCreationDate = record.date
            // Expire quickly: this is an on-demand snapshot, not permanent health-history publication.
            let item = CSSearchableItem(uniqueIdentifier: record.id,
                domainIdentifier: "DUNE.HealthQuery.Private", attributeSet: attributes)
            item.expirationDate = Date().addingTimeInterval(3600)
            return item
        }
    }
}
