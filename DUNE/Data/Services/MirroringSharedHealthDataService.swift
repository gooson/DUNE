import Foundation

/// Decorates SharedHealthDataService to persist fetched snapshots into
/// a CloudKit-synced mirror store.
actor MirroringSharedHealthDataService: SharedHealthDataService {
    private let baseService: SharedHealthDataService
    private let mirrorStore: HealthSnapshotMirroring

    init(
        baseService: SharedHealthDataService,
        mirrorStore: HealthSnapshotMirroring
    ) {
        self.baseService = baseService
        self.mirrorStore = mirrorStore
    }

    func fetchSnapshot() async -> SharedHealthSnapshot {
        let snapshot = await baseService.fetchSnapshot()
        Task(priority: .utility) { [mirrorStore] in
            await mirrorStore.persist(snapshot: snapshot)
        }
        return snapshot
    }

    func invalidateCache() async {
        await baseService.invalidateCache()
    }
}
