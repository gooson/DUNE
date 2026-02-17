import Foundation

extension Collection where Element: WorkoutSet {
    /// Formatted summary string for a collection of workout sets (e.g. "3 sets · 60kg · 30 reps")
    func setSummary() -> String? {
        let completed = filter(\.isCompleted)
        guard !completed.isEmpty else { return nil }

        var parts: [String] = []
        parts.append("\(completed.count) sets")

        let weights = completed.compactMap(\.weight).filter { $0 > 0 }
        if let minW = weights.min(), let maxW = weights.max() {
            if minW == maxW {
                parts.append("\(minW.formatted(.number.precision(.fractionLength(0...1))))kg")
            } else {
                parts.append("\(minW.formatted(.number.precision(.fractionLength(0...1))))-\(maxW.formatted(.number.precision(.fractionLength(0...1))))kg")
            }
        }

        let totalReps = completed.compactMap(\.reps).reduce(0, +)
        if totalReps > 0 {
            parts.append("\(totalReps) reps")
        }

        return parts.joined(separator: " \u{00B7} ")
    }
}

extension Collection where Element == PreviousSetInfo {
    /// Formatted summary for previous session sets
    func summary() -> String {
        var parts: [String] = ["\(count) sets"]

        let weights = compactMap(\.weight).filter { $0 > 0 }
        if let minW = weights.min(), let maxW = weights.max() {
            if minW == maxW {
                parts.append("\(minW.formatted(.number.precision(.fractionLength(0...1))))kg")
            } else {
                parts.append("\(minW.formatted(.number.precision(.fractionLength(0...1))))-\(maxW.formatted(.number.precision(.fractionLength(0...1))))kg")
            }
        }

        let totalReps = compactMap(\.reps).reduce(0, +)
        if totalReps > 0 {
            parts.append("\(totalReps) reps")
        }

        return parts.joined(separator: " \u{00B7} ")
    }
}
