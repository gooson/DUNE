import Foundation

enum WatchEffortInputPolicy {
    static let minimumEffort = 1
    static let maximumEffort = 10
    static let defaultEffort = 5
    static let hapticDebounceInterval: TimeInterval = 0.12

    static func clampedEffort(_ value: Int) -> Int {
        Swift.max(minimumEffort, Swift.min(maximumEffort, value))
    }

    static func descriptor(for effort: Int) -> String {
        switch clampedEffort(effort) {
        case 1...3: return String(localized: "Easy")
        case 4...6: return String(localized: "Moderate")
        case 7...8: return String(localized: "Hard")
        default: return String(localized: "All Out")
        }
    }

    static func shouldPlayHaptic(lastHapticDate: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastHapticDate) >= hapticDebounceInterval
    }
}
