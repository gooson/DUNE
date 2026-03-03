import Foundation

/// Persists shared health snapshots to a cross-device mirror store.
protocol HealthSnapshotMirroring: Sendable {
    func persist(snapshot: SharedHealthSnapshot) async
}
