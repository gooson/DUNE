import Foundation
import Testing
@testable import DUNE

@Suite("BodyPeerReference")
struct BodyPeerReferenceTests {
    @Test("Exact source means are not medians or interpolated five-year cohorts")
    func publishedReferenceAnchors() {
        let thirties = BodyPeerReference.Criteria(ageGroup: .thirties, sex: .male)
        #expect(BodyPeerReference.reference(metric: .weight, criteria: thirties).mean == 91.4)
        #expect(BodyPeerReference.reference(metric: .bmi, criteria: thirties).mean == 29.5)
        let oldestWomen = BodyPeerReference.Criteria(ageGroup: .eightyAndOlder, sex: .female)
        #expect(BodyPeerReference.reference(metric: .weight, criteria: oldestWomen).mean == 67.9)
        #expect(BodyPeerReference.reference(metric: .bmi, criteria: oldestWomen).mean == 27.7)
    }

    @Test("All supported exact cohorts provide finite positive source means",
          arguments: BodyPeerReference.AgeGroup.allCases, BodyPeerReference.SurveySex.allCases)
    func completeCohorts(age: BodyPeerReference.AgeGroup, sex: BodyPeerReference.SurveySex) {
        let criteria = BodyPeerReference.Criteria(ageGroup: age, sex: sex)
        for metric in BodyPeerReference.Metric.allCases {
            let reference = BodyPeerReference.reference(metric: metric, criteria: criteria)
            #expect(reference.criteria == criteria)
            #expect(reference.mean.isFinite)
            #expect(reference.mean > 0)
        }
    }

    @Test("Persisted unset and unsupported criteria do not become a default male age group",
          arguments: [("", ""), ("30-34", "male"), ("30-39", ""), ("30-39", "unknown"), ("under20", "female")])
    func unsupportedCriteria(values: (String, String)) {
        #expect(BodyPeerReference.Criteria(ageGroupRawValue: values.0, sexRawValue: values.1) == nil)
    }

    @Test("Published exact criteria round-trip without changing population")
    func criteriaRoundTrip() throws {
        let criteria = try #require(BodyPeerReference.Criteria(ageGroupRawValue: "40-49", sexRawValue: "female"))
        #expect(criteria == .init(ageGroup: .forties, sex: .female))
    }

    @Test("Difference remains current minus survey mean in canonical units")
    func descriptiveDifference() throws {
        let criteria = BodyPeerReference.Criteria(ageGroup: .thirties, sex: .male)
        let below = try BodyPeerReference.compare(canonicalValue: 68.4, metric: .weight, criteria: criteria)
        #expect(abs(below.difference - (-23)) < 0.000_001)
        let equal = try BodyPeerReference.compare(canonicalValue: 29.5, metric: .bmi, criteria: criteria)
        #expect(equal.difference == 0)
        let above = try BodyPeerReference.compare(canonicalValue: 35.5, metric: .bmi, criteria: criteria)
        #expect(above.difference == 6)
    }

    @Test("Invalid or out-of-range quantities never yield a comparison",
          arguments: [0.0, -1, Double.nan, Double.infinity, -Double.infinity, 501])
    func invalidWeight(value: Double) {
        #expect(throws: BodyPeerReference.ComparisonError.invalidMeasurement) {
            try BodyPeerReference.compare(
                canonicalValue: value, metric: .weight,
                criteria: .init(ageGroup: .twenties, sex: .female)
            )
        }
    }

    @Test("BMI is validated separately from kilograms")
    func invalidBMI() {
        #expect(throws: BodyPeerReference.ComparisonError.invalidMeasurement) {
            try BodyPeerReference.compare(
                canonicalValue: 100.1, metric: .bmi,
                criteria: .init(ageGroup: .sixties, sex: .male)
            )
        }
    }

    @Test("Boundary quantities are not clamped or assigned a health grade")
    func boundaries() throws {
        let criteria = BodyPeerReference.Criteria(ageGroup: .twenties, sex: .male)
        #expect(try BodyPeerReference.compare(canonicalValue: 500, metric: .weight, criteria: criteria).currentValue == 500)
        #expect(try BodyPeerReference.compare(canonicalValue: 100, metric: .bmi, criteria: criteria).currentValue == 100)
    }
}
