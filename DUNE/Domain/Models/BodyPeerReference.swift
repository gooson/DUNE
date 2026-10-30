import Foundation

/// Descriptive US adult survey means. These are neither health targets nor Korean norms.
/// Source: CDC/NCHS, Vital and Health Statistics Series 3 No.50, Tables 3 and 10.
/// Survey: NHANES August 2021–August 2023; pregnant women are excluded.
/// The report declares its material public domain. Attribution belongs in the source UI.
enum BodyPeerReference {
    enum Metric: String, CaseIterable, Sendable {
        case weight
        case bmi

        /// Values use kilograms for weight and kg/m² for BMI.
        fileprivate var validRange: ClosedRange<Double> {
            switch self {
            case .weight: 0...500
            case .bmi: 0...100
            }
        }
    }

    enum AgeGroup: String, CaseIterable, Sendable {
        case twenties = "20-29"
        case thirties = "30-39"
        case forties = "40-49"
        case fifties = "50-59"
        case sixties = "60-69"
        case seventies = "70-79"
        case eightyAndOlder = "80+"
    }

    /// Categories in the source survey; never inferred from language or user appearance.
    enum SurveySex: String, CaseIterable, Sendable {
        case male
        case female
    }

    /// The reference population the user explicitly selected, not an inferred user profile.
    struct Criteria: Equatable, Sendable {
        let ageGroup: AgeGroup
        let sex: SurveySex

        init(ageGroup: AgeGroup, sex: SurveySex) {
            self.ageGroup = ageGroup
            self.sex = sex
        }

        /// Empty, malformed, and unsupported persisted criteria stay unset.
        init?(ageGroupRawValue: String, sexRawValue: String) {
            guard let ageGroup = AgeGroup(rawValue: ageGroupRawValue),
                  let sex = SurveySex(rawValue: sexRawValue) else { return nil }
            self.init(ageGroup: ageGroup, sex: sex)
        }
    }

    struct Reference: Equatable, Sendable {
        let metric: Metric
        let criteria: Criteria
        let mean: Double

        fileprivate init(metric: Metric, criteria: Criteria, mean: Double) {
            self.metric = metric
            self.criteria = criteria
            self.mean = mean
        }
    }

    struct Comparison: Equatable, Sendable {
        let currentValue: Double
        let reference: Reference
        /// Current minus survey mean, in the reference's canonical unit.
        let difference: Double
    }

    enum ComparisonError: Error, Equatable {
        case invalidMeasurement
    }

    static let surveyPeriod = "2021–2023"
    static let reportIdentifier = "NCHS Series 3 No.50"
    static let sourceURL = URL(string: "https://stacks.cdc.gov/view/cdc/174595")!
    static let sourcePDFURL = URL(string: "https://stacks.cdc.gov/view/cdc/174595/cdc_174595_DS1.pdf")!

    static func reference(metric: Metric, criteria: Criteria) -> Reference {
        let values: (maleWeight: Double, femaleWeight: Double, maleBMI: Double, femaleBMI: Double)
        // Exact published age bins. Never interpolate a five-year cohort or substitute P50.
        switch criteria.ageGroup {
        case .twenties: values = (86.8, 74.8, 27.8, 28.0)
        case .thirties: values = (91.4, 80.9, 29.5, 30.5)
        case .forties: values = (95.3, 80.4, 30.5, 30.7)
        case .fifties: values = (92.1, 81.6, 30.2, 31.4)
        case .sixties: values = (89.2, 77.5, 29.2, 30.1)
        case .seventies: values = (87.7, 73.8, 29.4, 29.5)
        case .eightyAndOlder: values = (81.7, 67.9, 27.8, 27.7)
        }
        let mean: Double
        switch (metric, criteria.sex) {
        case (.weight, .male): mean = values.maleWeight
        case (.weight, .female): mean = values.femaleWeight
        case (.bmi, .male): mean = values.maleBMI
        case (.bmi, .female): mean = values.femaleBMI
        }
        return Reference(metric: metric, criteria: criteria, mean: mean)
    }

    static func compare(
        canonicalValue: Double,
        metric: Metric,
        criteria: Criteria
    ) throws -> Comparison {
        guard canonicalValue.isFinite, canonicalValue > 0,
              metric.validRange.contains(canonicalValue) else {
            throw ComparisonError.invalidMeasurement
        }
        let reference = reference(metric: metric, criteria: criteria)
        return Comparison(
            currentValue: canonicalValue,
            reference: reference,
            difference: canonicalValue - reference.mean
        )
    }
}
