import Foundation
import Testing
@testable import DUNEWatch

@Suite("WatchEffortInputPolicy")
struct WatchEffortInputPolicyTests {
    @Test("clampedEffort bounds value to 1...10")
    func clampedEffortBoundsValue() {
        #expect(WatchEffortInputPolicy.clampedEffort(-3) == 1)
        #expect(WatchEffortInputPolicy.clampedEffort(7) == 7)
        #expect(WatchEffortInputPolicy.clampedEffort(42) == 10)
    }

    @Test("descriptor maps effort buckets")
    func descriptorMapsEffortBuckets() {
        #expect(WatchEffortInputPolicy.descriptor(for: 2) == "Easy")
        #expect(WatchEffortInputPolicy.descriptor(for: 5) == "Moderate")
        #expect(WatchEffortInputPolicy.descriptor(for: 8) == "Hard")
        #expect(WatchEffortInputPolicy.descriptor(for: 10) == "All Out")
    }

    @Test("shouldPlayHaptic respects debounce interval")
    func shouldPlayHapticRespectsDebounceInterval() {
        let now = Date()
        let justPlayed = now.addingTimeInterval(-0.05)
        let oldPlay = now.addingTimeInterval(-0.5)

        #expect(!WatchEffortInputPolicy.shouldPlayHaptic(lastHapticDate: justPlayed, now: now))
        #expect(WatchEffortInputPolicy.shouldPlayHaptic(lastHapticDate: oldPlay, now: now))
    }
}
