import Foundation

/// Live, measured GPS altitude for an outdoor workout.
struct WatchElevationProfile: Sendable {
    struct Sample: Sendable {
        let date: Date
        let meters: Double
    }

    private(set) var samples: [Sample] = []
    private(set) var currentAltitude: Double?
    private(set) var ascentMeters = 0.0
    private var ascentAnchor: Double?
    static let maximumSamples = 1_800
    static let chartWindow: TimeInterval = 30 * 60
    static let chartBucketCount = 60
    static let minimumRiseMeters = 3.0

    func currentAltitude(at now: Date) -> Double? {
        guard let latest = samples.last, now.timeIntervalSince(latest.date) >= -1,
              now.timeIntervalSince(latest.date) <= 30 else { return nil }
        return currentAltitude
    }

    /// Oldest-first 30-second buckets; nil means no accepted GPS altitude in that interval.
    func chartBuckets(endingAt end: Date) -> [Double?] {
        let start = end.addingTimeInterval(-Self.chartWindow)
        var buckets = [Double?](repeating: nil, count: Self.chartBucketCount)
        for sample in samples where sample.date >= start && sample.date <= end {
            let index = min(Self.chartBucketCount - 1, Int(sample.date.timeIntervalSince(start) / 30))
            buckets[index] = sample.meters
        }
        return buckets
    }

    mutating func breakSegment() {
        ascentAnchor = nil
    }

    mutating func observe(altitude: Double?, at date: Date, beginsSegment: Bool) {
        if beginsSegment { breakSegment() }
        guard let altitude, altitude.isFinite else {
            currentAltitude = nil
            breakSegment()
            return
        }
        currentAltitude = altitude
        samples.append(Sample(date: date, meters: altitude))
        samples.removeAll { $0.date < date.addingTimeInterval(-Self.chartWindow) }
        if samples.count > Self.maximumSamples {
            samples.removeFirst(samples.count - Self.maximumSamples)
        }
        if let ascentAnchor {
            let change = altitude - ascentAnchor
            if change >= Self.minimumRiseMeters {
                ascentMeters += change
                self.ascentAnchor = altitude
            } else if change <= -Self.minimumRiseMeters {
                self.ascentAnchor = altitude
            }
        } else {
            ascentAnchor = altitude
        }
    }
}
