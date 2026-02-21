import Foundation

/// Heart rate zone distribution data from a workout.
struct HeartRateZone: Sendable, Identifiable {
    let zone: Zone
    let durationSeconds: TimeInterval
    let percentage: Double // 0.0-1.0

    var id: Int { zone.rawValue }

    enum Zone: Int, CaseIterable, Sendable, Comparable {
        case zone1 = 1 // Recovery (50-60% maxHR)
        case zone2 = 2 // Fat Burn (60-70%)
        case zone3 = 3 // Cardio (70-80%)
        case zone4 = 4 // Hard (80-90%)
        case zone5 = 5 // Peak (90-100%)

        /// HR range as fraction of maxHR (lower bound inclusive, upper bound exclusive except zone5).
        var hrFractionRange: ClosedRange<Double> {
            switch self {
            case .zone1: 0.50...0.60
            case .zone2: 0.60...0.70
            case .zone3: 0.70...0.80
            case .zone4: 0.80...0.90
            case .zone5: 0.90...1.00
            }
        }

        /// Determines the zone for a given HR fraction of maxHR.
        static func zone(forFraction fraction: Double) -> Zone? {
            guard fraction >= 0.50, fraction <= 1.0 else { return nil }
            if fraction >= 0.90 { return .zone5 }
            if fraction >= 0.80 { return .zone4 }
            if fraction >= 0.70 { return .zone3 }
            if fraction >= 0.60 { return .zone2 }
            return .zone1
        }

        static func < (lhs: Zone, rhs: Zone) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

/// Computes heart rate zones from raw HR samples.
enum HeartRateZoneCalculator {
    /// Default max HR estimation when age is unknown (assumes 30 years old).
    static let defaultMaxHR: Double = 190.0

    /// Computes max HR using 220 - age formula.
    static func estimateMaxHR(age: Int) -> Double {
        let maxHR = 220.0 - Double(age)
        // Guard against unreasonable values
        guard maxHR > 100, maxHR < 230 else { return defaultMaxHR }
        return maxHR
    }

    /// Computes zone distribution from heart rate samples.
    /// - Parameters:
    ///   - samples: Time-ordered HR samples with timestamps
    ///   - maxHR: Estimated maximum heart rate
    /// - Returns: Zone distribution array (always 5 elements, one per zone)
    static func computeZones(
        samples: [HeartRateSample],
        maxHR: Double
    ) -> [HeartRateZone] {
        guard maxHR > 0, samples.count >= 2 else {
            return HeartRateZone.Zone.allCases.map {
                HeartRateZone(zone: $0, durationSeconds: 0, percentage: 0)
            }
        }

        var zoneDurations: [HeartRateZone.Zone: TimeInterval] = [:]
        for zone in HeartRateZone.Zone.allCases {
            zoneDurations[zone] = 0
        }

        var totalDuration: TimeInterval = 0

        for i in 0..<(samples.count - 1) {
            let current = samples[i]
            let next = samples[i + 1]
            let interval = next.date.timeIntervalSince(current.date)

            // Skip unreasonable intervals (> 5 minutes between samples)
            guard interval > 0, interval < 300 else { continue }

            let fraction = current.bpm / maxHR
            if let zone = HeartRateZone.Zone.zone(forFraction: fraction) {
                zoneDurations[zone, default: 0] += interval
                totalDuration += interval
            }
        }

        guard totalDuration > 0 else {
            return HeartRateZone.Zone.allCases.map {
                HeartRateZone(zone: $0, durationSeconds: 0, percentage: 0)
            }
        }

        return HeartRateZone.Zone.allCases.map { zone in
            let duration = zoneDurations[zone] ?? 0
            let pct = duration / totalDuration
            // Correction #18: verify computed values
            let safePct = pct.isNaN || pct.isInfinite ? 0 : pct
            return HeartRateZone(zone: zone, durationSeconds: duration, percentage: safePct)
        }
    }
}
