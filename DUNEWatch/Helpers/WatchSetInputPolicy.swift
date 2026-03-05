import Foundation

enum WatchSetInputPolicy {
    static let defaultReps = 10
    static let minimumReps = 1
    static let maximumEditableReps = 100
    static let maximumCompletionReps = 1000

    static func resolvedInitialReps(lastSetReps: Int?, entryDefaultReps: Int) -> Int {
        if let lastSetReps, (minimumReps...maximumCompletionReps).contains(lastSetReps) {
            return lastSetReps
        }
        if (minimumReps...maximumCompletionReps).contains(entryDefaultReps) {
            return entryDefaultReps
        }
        return defaultReps
    }

    static func isValidForCompletion(reps: Int) -> Bool {
        (minimumReps...maximumCompletionReps).contains(reps)
    }
}
