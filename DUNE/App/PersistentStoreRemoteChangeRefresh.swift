import Foundation

enum PersistentStoreRemoteChangeRefresh {
    @MainActor
    static func request(using refreshCoordinator: AppRefreshCoordinating) async {
        _ = await refreshCoordinator.requestRefresh(source: .cloudKitRemoteChange)
    }
}
