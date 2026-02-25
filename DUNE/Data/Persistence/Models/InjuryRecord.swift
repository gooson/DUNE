import Foundation
import SwiftData

@Model
final class InjuryRecord {
    var id: UUID = UUID()
    var bodyPartRaw: String = ""
    var bodySideRaw: String?
    var severityRaw: Int = 1
    var startDate: Date = Date()
    var endDate: Date?
    var memo: String = ""
    var createdAt: Date = Date()

    // MARK: - Computed Properties

    var bodyPart: BodyPart {
        BodyPart(rawValue: bodyPartRaw) ?? .knee
    }

    var bodySide: BodySide? {
        bodySideRaw.flatMap { BodySide(rawValue: $0) }
    }

    var severity: InjurySeverity {
        InjurySeverity(rawValue: severityRaw) ?? .minor
    }

    var isActive: Bool { endDate == nil }

    var durationDays: Int {
        let end = endDate ?? Date()
        return Swift.max(0, Calendar.current.dateComponents([.day], from: startDate, to: end).day ?? 0)
    }

    // MARK: - Domain DTO Conversion

    func toInjuryInfo() -> InjuryInfo {
        InjuryInfo(
            id: id,
            bodyPart: bodyPart,
            bodySide: bodySide,
            severity: severity,
            startDate: startDate,
            endDate: endDate,
            memo: memo
        )
    }

    // MARK: - Init

    init(
        bodyPart: BodyPart,
        bodySide: BodySide?,
        severity: InjurySeverity,
        startDate: Date,
        endDate: Date? = nil,
        memo: String = ""
    ) {
        self.id = UUID()
        self.bodyPartRaw = bodyPart.rawValue
        self.bodySideRaw = bodySide?.rawValue
        self.severityRaw = severity.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.memo = memo
        self.createdAt = Date()
    }
}
