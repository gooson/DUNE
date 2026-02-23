import Foundation

/// A single daily sample point for vital sign trends.
struct DailySample: Sendable, Hashable {
    let date: Date
    let value: Double
}

/// A single daily sleep sample with duration in minutes.
struct SleepDailySample: Sendable, Hashable {
    let date: Date
    let minutes: Double
}
