import Foundation
import SwiftData

@Model
final class BodyCompositionRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var weight: Double?
    var bodyFatPercentage: Double?
    var muscleMass: Double?
    var memo: String = ""
    var createdAt: Date = Date()

    init(
        date: Date = Date(),
        weight: Double? = nil,
        bodyFatPercentage: Double? = nil,
        muscleMass: Double? = nil,
        memo: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
        self.muscleMass = muscleMass
        self.memo = memo
        self.createdAt = Date()
    }
}
