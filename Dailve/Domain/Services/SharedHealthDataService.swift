import Foundation

protocol SharedHealthDataService: Sendable {
    func fetchSnapshot() async -> SharedHealthSnapshot
    func invalidateCache() async
}
