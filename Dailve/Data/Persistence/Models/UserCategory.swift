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
        self.name = String(name.prefix(50))
        self.iconName = iconName.isEmpty ? "tag.fill" : iconName
        // Validate hex is exactly 6 hex characters
        let sanitizedHex = colorHex.replacingOccurrences(of: "#", with: "")
        self.colorHex = sanitizedHex.count == 6 ? sanitizedHex : "007AFF"
        self.defaultInputTypeRaw = defaultInputType.rawValue
        self.sortOrder = max(sortOrder, 0)
        self.createdAt = Date()
    }

    // MARK: - Typed Accessors

    var defaultInputType: ExerciseInputType {
        ExerciseInputType(rawValue: defaultInputTypeRaw) ?? .setsRepsWeight
    }
}
