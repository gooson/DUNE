import SwiftUI
import HealthKit
import SwiftData
import CloudKit

@MainActor
struct NearbyWorkoutSyncModifier: ViewModifier {
    let healthService: any SharedHealthDataService

    @Environment(\.scenePhase) private var phase
    @Environment(\.modelContext) private var modelContext
    @AppStorage(NearbyWorkoutTransfer.preferenceKey) private var enabled = false
    @State private var transfer = NearbyWorkoutTransfer()

    func body(content: Content) -> some View {
        content
            .task(id: enabled && phase != .background) { configure() }
            .onReceive(NotificationCenter.default.publisher(for: .NSUbiquityIdentityDidChange)) { _ in
                configure()
                NotificationCenter.default.post(name: NearbyWorkoutCache.didChange, object: nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
                configure()
                NotificationCenter.default.post(name: NearbyWorkoutCache.didChange, object: nil)
            }
            .onDisappear { transfer.stop() }
    }

    private func configure() {
        transfer.stop()
        guard enabled, phase != .background else { return }
        if ProcessInfo.processInfo.isiOSAppOnMac {
            transfer.startReceiving(request: { source, scope in
                try await NearbyWorkoutCache.shared.request(source: source, scope: scope)
            }, consume: { data, scope in
                guard scope == (try await NearbyWorkoutTransfer.accountScope()) else { throw CocoaError(.userCancelled) }
                try await NearbyWorkoutCache.shared.accept(data, scope: scope)
            })
        } else if HKHealthStore.isHealthDataAvailable() {
            transfer.startPublishing { request in
                let snapshot = request.includesHealthSnapshot
                    ? HealthSnapshotMirrorMapper.makePayload(from: await healthService.fetchSnapshot()) : nil
                let locations = try savedLocations()
                return try await NearbyWorkoutHistory.capture(request: request, savedLocations: locations.values,
                                                              locationEditDates: locations.dates, healthSnapshot: snapshot)
            }
        }
    }

    private func savedLocations() throws -> (values: [String: WorkoutLocationPayload], dates: [String: Date]) {
        let locations = try modelContext.fetch(FetchDescriptor<WorkoutLocationRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        ))
        guard !locations.isEmpty else { return ([:], [:]) }
        let linked = try modelContext.fetch(FetchDescriptor<ExerciseRecord>(
            predicate: #Predicate { $0.healthKitWorkoutID != nil }
        ))
        var ids = [UUID: String]()
        for record in linked { ids[record.id] = record.healthKitWorkoutID }
        var result = [String: WorkoutLocationPayload]()
        var dates = [String: Date]()
        for location in locations {
            guard let key = location.healthKitWorkoutID ?? location.localRecordID.flatMap({ ids[$0] }),
                  result[key.uppercased()] == nil, let payload = location.payload else { continue }
            result[key.uppercased()] = payload
            dates[key.uppercased()] = location.updatedAt
        }
        return (result, dates)
    }

}
