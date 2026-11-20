import Foundation
import Testing
@testable import DUNEWatch

@Suite("Watch heart-rate history")
struct WatchHeartRateHistoryTests {
    @Test("Reception gaps stay empty in the rolling 30-minute chart")
    func gapsAndBoundary() {
        let now = Date(timeIntervalSince1970: 10_000)
        var history = WatchHeartRateHistory()
        history.append(bpm: 100, at: now.addingTimeInterval(-1_800), receivedAt: now)
        history.append(bpm: 120, at: now.addingTimeInterval(-60), receivedAt: now)
        history.append(bpm: 130, at: now, receivedAt: now)
        let buckets = history.minuteBuckets(endingAt: now)
        #expect(buckets.count == 30)
        #expect(buckets[0] == 100)
        #expect(buckets[29] == 130)
        #expect(buckets[12] == nil)
    }

    @Test("History rejects invalid BPM and bounds memory")
    func validationAndBound() {
        let now = Date(timeIntervalSince1970: 10_000)
        var history = WatchHeartRateHistory()
        history.append(bpm: .nan, at: now, receivedAt: now)
        history.append(bpm: 0, at: now, receivedAt: now)
        #expect(history.samples.isEmpty)
        for index in 0..<400 {
            history.append(bpm: 100, at: now.addingTimeInterval(Double(index)), receivedAt: now.addingTimeInterval(Double(index)))
        }
        #expect(history.samples.count == WatchHeartRateHistory.maximumSamples)
        #expect(history.samples.first?.date == now.addingTimeInterval(40))
        history.append(bpm: 110, at: now, receivedAt: now.addingTimeInterval(400))
        #expect(history.samples.count == WatchHeartRateHistory.maximumSamples)
    }
    @Test("Delayed readings keep measurement time; duplicates and out-of-order callbacks are ignored")
    func delayedAndRepeatedCallbacks() {
        let now = Date(timeIntervalSince1970: 10_000)
        var history = WatchHeartRateHistory()
        let measured = now.addingTimeInterval(-120)
        let acceptedMeasurement = history.append(bpm: 120, at: measured, receivedAt: now)
        #expect(acceptedMeasurement)
        let acceptedDuplicate = history.append(bpm: 120, at: measured, receivedAt: now.addingTimeInterval(1))
        #expect(!acceptedDuplicate)
        let acceptedOutOfOrder = history.append(
            bpm: 115, at: measured.addingTimeInterval(-30), receivedAt: now.addingTimeInterval(1)
        )
        #expect(!acceptedOutOfOrder)
        let acceptedStale = history.append(bpm: 130, at: now.addingTimeInterval(-1_801), receivedAt: now)
        #expect(!acceptedStale)
        #expect(history.samples.count == 1)
        let buckets = history.minuteBuckets(endingAt: now)
        #expect(buckets[28] == 120)
        #expect(buckets[29] == nil)
    }

}
