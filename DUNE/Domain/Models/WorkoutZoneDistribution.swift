import Foundation
import HealthKit

/// Zone boundaries and time distribution retained from a HealthKit workout.
struct WorkoutZoneDistribution: Sendable {
    enum Source: Sendable, Equatable {
        case system
        case user
        case app
        case estimated
        case unknown
    }

    struct Bin: Sendable {
        let index: Int
        let minimumBPM: Double?
        let maximumBPM: Double?
        let durationSeconds: TimeInterval
    }

    struct Zone: Sendable, Identifiable {
        let index: Int
        let minimumBPM: Double?
        let maximumBPM: Double?
        let durationSeconds: TimeInterval
        let percentage: Double

        var id: Int { index }
    }

    let source: Source
    let zones: [Zone]

    init(source: Source, bins: [Bin]) {
        self.source = source
        let ordered = bins.sorted { $0.index < $1.index }
        let durations = ordered.map { bin in
            bin.durationSeconds.isFinite && bin.durationSeconds > 0 ? bin.durationSeconds : 0
        }
        let total = durations.reduce(0, +)
        zones = zip(ordered, durations).map { bin, duration in
            Zone(
                index: bin.index,
                minimumBPM: bin.minimumBPM,
                maximumBPM: bin.maximumBPM,
                durationSeconds: duration,
                percentage: total > 0 ? duration / total : 0
            )
        }
    }

    init(group: HKWorkoutZoneGroup) {
        let source: Source
        switch group.configuration.source {
        case .system: source = .system
        case .user: source = .user
        case .app: source = .app
        @unknown default: source = .unknown
        }
        let durations = Dictionary(grouping: group.zoneDurations, by: { $0.zone.index })
            .mapValues { $0.reduce(0) { $0 + $1.duration } }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let bins = group.configuration.zones.map { zone in
            Bin(
                index: zone.index,
                minimumBPM: zone.minimum?.doubleValue(for: bpm),
                maximumBPM: zone.maximum?.doubleValue(for: bpm),
                durationSeconds: durations[zone.index] ?? 0
            )
        }
        self.init(source: source, bins: bins)
    }
}
