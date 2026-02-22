import Foundation

// MARK: - Shared Summary Formatting

private func formatWeightRange(_ weights: [Double]) -> String? {
    guard let minW = weights.min(), let maxW = weights.max() else { return nil }
    let fmt: (Double) -> String = { $0.formatted(.number.precision(.fractionLength(0...1))) }
    if minW == maxW {
        return "\(fmt(minW))kg"
    }
    return "\(fmt(minW))-\(fmt(maxW))kg"
}

private func formatSetSummary(count: Int, weights: [Double], totalReps: Int) -> String {
    var parts: [String] = ["\(count.formattedWithSeparator) sets"]
    if let weightStr = formatWeightRange(weights) {
        parts.append(weightStr)
    }
    if totalReps > 0 {
        parts.append("\(totalReps.formattedWithSeparator) reps")
    }
    return parts.joined(separator: " \u{00B7} ")
}

// MARK: - Collection Extensions

extension Collection where Element: WorkoutSet {
    /// Formatted summary string for a collection of workout sets (e.g. "3 sets · 60kg · 30 reps")
    func setSummary() -> String? {
        let completed = filter(\.isCompleted)
        guard !completed.isEmpty else { return nil }
        return formatSetSummary(
            count: completed.count,
            weights: completed.compactMap(\.weight).filter { $0 > 0 },
            totalReps: completed.compactMap(\.reps).reduce(0, +)
        )
    }
}

extension Collection where Element == PreviousSetInfo {
    /// Formatted summary for previous session sets
    func summary() -> String {
        formatSetSummary(
            count: count,
            weights: compactMap(\.weight).filter { $0 > 0 },
            totalReps: compactMap(\.reps).reduce(0, +)
        )
    }
}
