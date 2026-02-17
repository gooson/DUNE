import Foundation

enum ExerciseCategory: String, Codable, CaseIterable, Sendable {
    case strength
    case cardio
    case hiit
    case flexibility
    case bodyweight
}

enum ExerciseInputType: String, Codable, Sendable {
    /// Strength: sets x reps x weight (kg)
    case setsRepsWeight
    /// Bodyweight: sets x reps (weight optional)
    case setsReps
    /// Cardio: duration + distance
    case durationDistance
    /// Flexibility: duration + intensity (1-10)
    case durationIntensity
    /// HIIT: rounds x time + rest
    case roundsBased
}

enum SetType: String, Codable, Sendable {
    case warmup
    case working
    case drop
    case failure
}

enum CalorieSource: String, Codable, Sendable {
    case healthKit
    case met
    case manual
}
