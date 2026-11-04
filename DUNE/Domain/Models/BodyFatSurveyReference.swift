import Foundation

/// Descriptive US adult whole-body DXA percent-body-fat means, not health targets.
/// CDC/NCHS Series 11 No. 250, Table 3 (printed p. 12, PDF p. 18), NHANES 1999–2004.
/// https://www.cdc.gov/nchs/data/series/sr_11/sr11_250.pdf
/// The report declares its material public domain; show attribution and method in the UI.
enum BodyFatSurveyReference {
    enum AgeGroup: String, CaseIterable, Sendable {
        case twentyToThirtyNine = "20–39"
        case fortyToFiftyNine = "40–59"
        case sixtyToSeventyNine = "60–79"
        case eightyAndOlder = "80+"
    }

    struct Reference: Equatable, Sendable {
        let ageGroup: AgeGroup
        let sex: BodyPeerReference.SurveySex
        /// Weighted survey mean in percentage points, not a fraction or percentile.
        let meanPercent: Double
    }

    struct Display: Equatable, Sendable {
        /// The app's already-converted percentage-point reading. Never multiply again.
        let recordedPercent: Double
        let reference: Reference
    }

    enum MeasurementError: Error, Equatable {
        case invalidPercent
    }

    static let surveyPeriod = "1999–2004"
    static let reportIdentifier = "NCHS Series 11 No. 250, Table 3"
    static let sourcePDFURL = URL(string: "https://www.cdc.gov/nchs/data/series/sr_11/sr11_250.pdf")!

    static func broadAgeGroup(for ageGroup: BodyPeerReference.AgeGroup) -> AgeGroup {
        switch ageGroup {
        case .twenties, .thirties: .twentyToThirtyNine
        case .forties, .fifties: .fortyToFiftyNine
        case .sixties, .seventies: .sixtyToSeventyNine
        case .eightyAndOlder: .eightyAndOlder
        }
    }

    static func reference(criteria: BodyPeerReference.Criteria) -> Reference {
        let ageGroup = broadAgeGroup(for: criteria.ageGroup)
        let mean: Double
        switch (criteria.sex, ageGroup) {
        case (.male, .twentyToThirtyNine): mean = 26.1
        case (.male, .fortyToFiftyNine): mean = 28.6
        case (.male, .sixtyToSeventyNine): mean = 30.8
        case (.male, .eightyAndOlder): mean = 30.7
        case (.female, .twentyToThirtyNine): mean = 37.8
        case (.female, .fortyToFiftyNine): mean = 40.5
        case (.female, .sixtyToSeventyNine): mean = 42.4
        case (.female, .eightyAndOlder): mean = 40.4
        }
        return Reference(ageGroup: ageGroup, sex: criteria.sex, meanPercent: mean)
    }

    /// Accepts the app's canonical percent-point value (0...100), never a HealthKit fraction.
    static func display(recordedPercent: Double, criteria: BodyPeerReference.Criteria) throws -> Display {
        guard recordedPercent.isFinite, (0...100).contains(recordedPercent) else {
            throw MeasurementError.invalidPercent
        }
        return Display(recordedPercent: recordedPercent, reference: reference(criteria: criteria))
    }
}
