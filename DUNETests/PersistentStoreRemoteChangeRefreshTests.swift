import Foundation
import Testing
@testable import DUNE

private actor MockPersistentStoreRemoteChangeRefreshCoordinator: AppRefreshCoordinating {
    let requestResult: Bool
    private(set) var requestedSources: [RefreshSource] = []

    init(requestResult: Bool = true) {
        self.requestResult = requestResult
    }

    func requestRefresh(source: RefreshSource) async -> Bool {
        requestedSources.append(source)
        return requestResult
    }

    func forceRefresh() async {}

    func invalidateCacheOnly() async {}

    nonisolated var refreshNeededStream: AsyncStream<RefreshSource> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

@Suite("PersistentStoreRemoteChangeRefresh")
struct PersistentStoreRemoteChangeRefreshTests {
    @MainActor
    @Test("forwards cloudKit remote change source to the coordinator")
    func forwardsCloudKitRemoteChangeSource() async {
        let coordinator = MockPersistentStoreRemoteChangeRefreshCoordinator()

        await PersistentStoreRemoteChangeRefresh.request(using: coordinator)

        let requestedSources = await coordinator.requestedSources
        #expect(requestedSources == [.cloudKitRemoteChange])
    }

    @MainActor
    @Test("completes even when the coordinator reports a throttled refresh")
    func completesWhenRefreshIsThrottled() async {
        let coordinator = MockPersistentStoreRemoteChangeRefreshCoordinator(requestResult: false)

        await PersistentStoreRemoteChangeRefresh.request(using: coordinator)

        let requestedSources = await coordinator.requestedSources
        #expect(requestedSources.count == 1)
        #expect(requestedSources.first == .cloudKitRemoteChange)
    }
}
