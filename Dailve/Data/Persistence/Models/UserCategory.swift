import Foundation
import SwiftData

/// User-defined exercise category stored in SwiftData
@Model
final class UserCategory {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "tag.fill"
    var colorHex: String = "007AFF"  // Default blue
    var defaultInputTypeRaw: String = ExerciseInputType.setsRepsWeight.rawValue
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(
        name: String,
        iconName: String = "tag.fill",
        colorHex: String = "007AFF",
        defaultInputType: ExerciseInputType = .setsRepsWeight,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.defaultInputTypeRaw = defaultInputType.rawValue
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    // MARK: - Typed Accessors

    var defaultInputType: ExerciseInputType {
        ExerciseInputType(rawValue: defaultInputTypeRaw) ?? .setsRepsWeight
    }
}
