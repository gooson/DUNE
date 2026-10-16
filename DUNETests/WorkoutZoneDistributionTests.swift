import Foundation
import Testing
@testable import DUNE

@Suite("Workout zone distribution")
struct WorkoutZoneDistributionTests {
    @Test("HealthKit configurations keep their variable zone counts", arguments: [3, 5, 6, 9])
    func variableZoneCount(count: Int) {
        let bins = (1...count).map { index in
            WorkoutZoneDistribution.Bin(
                index: index,
                minimumBPM: index == 1 ? nil : Double(90 + index * 10),
                maximumBPM: index == count ? nil : Double(100 + index * 10),
                durationSeconds: Double(index * 60)
            )
        }
        let distribution = WorkoutZoneDistribution(source: .user, bins: Array(bins.reversed()))

        #expect(distribution.source == .user)
        #expect(distribution.zones.count == count)
        #expect(distribution.zones.map(\.index) == Array(1...count))
        #expect(distribution.zones.first?.minimumBPM == nil)
        #expect(distribution.zones.last?.maximumBPM == nil)
        #expect(abs(distribution.zones.map(\.percentage).reduce(0, +) - 1) < 0.000_001)
    }

    @Test("Unavailable or invalid zone duration cannot corrupt percentages")
    func invalidDuration() {
        let distribution = WorkoutZoneDistribution(source: .system, bins: [
            .init(index: 1, minimumBPM: nil, maximumBPM: 120, durationSeconds: -10),
            .init(index: 2, minimumBPM: 120, maximumBPM: 150, durationSeconds: .nan),
            .init(index: 3, minimumBPM: 150, maximumBPM: nil, durationSeconds: 30)
        ])

        #expect(distribution.zones.map(\.durationSeconds) == [0, 0, 30])
        #expect(distribution.zones.map(\.percentage) == [0, 0, 1])
    }

    @Test("Zero duration keeps all configured zones visible without a false share")
    func zeroDuration() {
        let distribution = WorkoutZoneDistribution(source: .app, bins: [
            .init(index: 1, minimumBPM: nil, maximumBPM: 130, durationSeconds: 0),
            .init(index: 2, minimumBPM: 130, maximumBPM: nil, durationSeconds: 0)
        ])

        #expect(distribution.zones.count == 2)
        #expect(distribution.zones.allSatisfy { $0.percentage == 0 })
    }
}
