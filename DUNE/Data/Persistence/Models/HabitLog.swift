import Foundation
import SwiftData

@Model
final class HabitLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var value: Double = 0
    var isAutoCompleted: Bool = false
    var completedAt: Date?
    var memo: String?

    var habitDefinition: HabitDefinition?

    // MARK: - Init

    init(
        date: Date,
        value: Double,
        isAutoCompleted: Bool = false,
        completedAt: Date? = nil,
        memo: String? = nil
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.value = value
        self.isAutoCompleted = isAutoCompleted
        self.completedAt = completedAt ?? Date()
        self.memo = memo
    }
}
