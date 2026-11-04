import Foundation
import Testing
@testable import DUNE

@Suite("BodyFatSurveyReference")
struct BodyFatSurveyReferenceTests {
    @Test("Table 3 weighted means use the four published broad age groups")
    func exactPublishedMeans() {
        let rows: [(BodyPeerReference.SurveySex, [Double])] = [
            (.male, [26.1, 28.6, 30.8, 30.7]),
            (.female, [37.8, 40.5, 42.4, 40.4]),
        ]
        for (sex, expected) in rows {
            for (index, ageGroup) in BodyFatSurveyReference.AgeGroup.allCases.enumerated() {
                let selected: BodyPeerReference.AgeGroup = switch ageGroup {
                case .twentyToThirtyNine: .twenties
                case .fortyToFiftyNine: .forties
                case .sixtyToSeventyNine: .sixties
                case .eightyAndOlder: .eightyAndOlder
                }
                let reference = BodyFatSurveyReference.reference(
                    criteria: .init(ageGroup: selected, sex: sex)
                )
                #expect(reference.ageGroup == ageGroup)
                #expect(reference.sex == sex)
                #expect(reference.meanPercent == expected[index])
            }
        }
        #expect(BodyFatSurveyReference.surveyPeriod == "1999–2004")
        #expect(BodyFatSurveyReference.reportIdentifier.contains("Table 3"))
        #expect(BodyFatSurveyReference.sourcePDFURL.absoluteString ==
                "https://www.cdc.gov/nchs/data/series/sr_11/sr11_250.pdf")
    }

    @Test("Every existing selection maps to its real DXA interval without interpolation")
    func mapping() {
        let expected: [(BodyPeerReference.AgeGroup, BodyFatSurveyReference.AgeGroup)] = [
            (.twenties, .twentyToThirtyNine), (.thirties, .twentyToThirtyNine),
            (.forties, .fortyToFiftyNine), (.fifties, .fortyToFiftyNine),
            (.sixties, .sixtyToSeventyNine), (.seventies, .sixtyToSeventyNine),
            (.eightyAndOlder, .eightyAndOlder),
        ]
        for (selected, broad) in expected {
            #expect(BodyFatSurveyReference.broadAgeGroup(for: selected) == broad)
        }
        #expect(BodyPeerReference.Criteria(ageGroupRawValue: "19-20", sexRawValue: "male") == nil)
        #expect(BodyPeerReference.Criteria(ageGroupRawValue: "30-39", sexRawValue: "unknown") == nil)
    }

    @Test("The displayed reading remains canonical percentage points and is never a comparison delta")
    func percentPoints() throws {
        let criteria = BodyPeerReference.Criteria(ageGroup: .thirties, sex: .female)
        let display = try BodyFatSurveyReference.display(recordedPercent: 17.8, criteria: criteria)
        #expect(display.recordedPercent == 17.8)
        #expect(display.reference.meanPercent == 37.8)
        #expect(display.reference.ageGroup == .twentyToThirtyNine)
        #expect(try BodyFatSurveyReference.display(recordedPercent: 0, criteria: criteria).recordedPercent == 0)
        #expect(try BodyFatSurveyReference.display(recordedPercent: 100, criteria: criteria).recordedPercent == 100)
    }

    @Test("Invalid supplied percentage points never yield a displayed own value",
          arguments: [Double.nan, Double.infinity, -Double.infinity, -0.1, 100.1])
    func invalidPercent(value: Double) {
        #expect(throws: BodyFatSurveyReference.MeasurementError.invalidPercent) {
            try BodyFatSurveyReference.display(
                recordedPercent: value,
                criteria: .init(ageGroup: .twenties, sex: .male)
            )
        }
    }
}
