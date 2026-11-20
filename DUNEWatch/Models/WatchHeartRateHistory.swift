import Foundation

/// A bounded, timestamped view of accepted live heart-rate readings.
struct WatchHeartRateHistory: Sendable {
    struct Sample: Sendable {
        let date: Date
        let bpm: Double
    }

    private(set) var samples: [Sample] = []
    static let window: TimeInterval = 30 * 60
    static let maximumSamples = 360

    @discardableResult
    mutating func append(bpm: Double, at date: Date, receivedAt now: Date) -> Bool {
        guard (20...250).contains(bpm), date.timeIntervalSince1970.isFinite else { return false }
        let age = now.timeIntervalSince(date)
        guard age >= -1, age <= Self.window else { return false }
        guard samples.last.map({ date > $0.date }) ?? true else { return false }
        samples.append(Sample(date: date, bpm: bpm))
        let cutoff = date.addingTimeInterval(-Self.window)
        samples.removeAll { $0.date < cutoff }
        if samples.count > Self.maximumSamples {
            samples.removeFirst(samples.count - Self.maximumSamples)
        }
        return true
    }

    /// Oldest-first minute buckets. A nil slot is a real reception gap.
    func minuteBuckets(endingAt end: Date) -> [Double?] {
        let start = end.addingTimeInterval(-Self.window)
        var buckets = [Double?](repeating: nil, count: 30)
        for sample in samples where sample.date >= start && sample.date <= end {
            let index = min(29, Int(sample.date.timeIntervalSince(start) / 60))
            buckets[index] = sample.bpm
        }
        return buckets
    }
}
