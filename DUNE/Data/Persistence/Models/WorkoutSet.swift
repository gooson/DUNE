import Foundation
import SwiftData

@Model
final class WorkoutSet {
    var id: UUID = UUID()
    var exerciseRecord: ExerciseRecord?
    var setNumber: Int = 0
    var setTypeRaw: String = SetType.working.rawValue
    var weight: Double?
    var reps: Int?
    var duration: TimeInterval?
    var distance: Double?
    var intensity: Int? = nil
    var isCompleted: Bool = false
    var restDuration: TimeInterval?

    init(
        setNumber: Int = 0,
        setType: SetType = .working,
        weight: Double? = nil,
        reps: Int? = nil,
        duration: TimeInterval? = nil,
        distance: Double? = nil,
        intensity: Int? = nil,
        isCompleted: Bool = false,
        restDuration: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.setNumber = setNumber
        self.setTypeRaw = setType.rawValue
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.distance = distance
        self.intensity = intensity
        self.isCompleted = isCompleted
        self.restDuration = restDuration
    }

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .working }
        set { setTypeRaw = newValue.rawValue }
    }
}
