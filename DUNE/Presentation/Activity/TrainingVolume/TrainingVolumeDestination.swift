import Foundation

/// Navigation destinations for the training volume analysis flow.
enum TrainingVolumeDestination: Hashable {
    case overview
    case exerciseType(typeKey: String, displayName: String, categoryRawValue: String, equipmentRawValue: String?)
}
