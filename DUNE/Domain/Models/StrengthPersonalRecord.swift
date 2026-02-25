import Foundation

/// Personal record for a strength exercise (session max weight).
struct StrengthPersonalRecord: Sendable, Hashable, Identifiable {
    let id: String  // exerciseDefinitionID or exerciseType
    let exerciseName: String
    let maxWeight: Double
    let date: Date
    let isRecent: Bool  // Updated within last 7 days

    init(exerciseName: String, maxWeight: Double, date: Date, referenceDateForRecent: Date = Date()) {
        self.id = exerciseName
        self.exerciseName = exerciseName
        self.maxWeight = max(0, min(500, maxWeight))  // Correction #22: weight 0-500
        self.date = date

        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: date, to: referenceDateForRecent).day ?? 0
        self.isRecent = daysDiff >= 0 && daysDiff <= 7
    }
}
