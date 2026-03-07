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
        let easy = WatchEffortInputPolicy.descriptor(for: 2)
        let moderate = WatchEffortInputPolicy.descriptor(for: 5)
        let hard = WatchEffortInputPolicy.descriptor(for: 8)
        let allOut = WatchEffortInputPolicy.descriptor(for: 10)

        #expect(easy == WatchEffortInputPolicy.descriptor(for: 3))
        #expect(moderate == WatchEffortInputPolicy.descriptor(for: 4))
        #expect(hard == WatchEffortInputPolicy.descriptor(for: 7))
        #expect(allOut == WatchEffortInputPolicy.descriptor(for: 9))

        #expect(easy != moderate)
        #expect(moderate != hard)
        #expect(hard != allOut)
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
