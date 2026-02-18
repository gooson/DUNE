import Foundation

/// App-level workout constants shared across Presentation layer.
/// Prevents cross-ViewModel coupling for common workout parameters.
enum WorkoutDefaults {
    /// Default number of sets for a new workout session
    static let setCount = 5
}
