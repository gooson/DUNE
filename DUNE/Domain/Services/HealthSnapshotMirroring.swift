import Foundation

/// Persists shared health snapshots to a cross-device mirror store.
protocol HealthSnapshotMirroring: Sendable {
    var isEnabled: Bool { get }
    func persist(snapshot: SharedHealthSnapshot) async
}
