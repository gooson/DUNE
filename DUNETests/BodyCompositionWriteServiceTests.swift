import Foundation
import HealthKit
import Testing
@testable import DUNE

@Suite("BodyCompositionWriteInput")
struct BodyCompositionWriteServiceTests {
    @Test("makeSamples builds HealthKit quantity samples for entered measurements")
    func makeSamplesBuildsExpectedTypes() {
        let date = Date(timeIntervalSince1970: 1_234)
        let input = BodyCompositionWriteInput(
            date: date,
            weight: 72.5,
            bodyFatPercentage: 18.0,
            leanBodyMass: 31.2
        )

        let samples = input.makeSamples()

        #expect(samples.count == 3)
        #expect(samples[0].sampleType == HKQuantityType(.bodyMass))
        #expect(samples[0].quantity.doubleValue(for: .gramUnit(with: .kilo)) == 72.5)
        #expect(samples[1].sampleType == HKQuantityType(.bodyFatPercentage))
        #expect(samples[1].quantity.doubleValue(for: .percent()) == 0.18)
        #expect(samples[2].sampleType == HKQuantityType(.leanBodyMass))
        #expect(samples[2].quantity.doubleValue(for: .gramUnit(with: .kilo)) == 31.2)
    }

    @Test("makeSamples skips nil measurements")
    func makeSamplesSkipsNilValues() {
        let input = BodyCompositionWriteInput(
            date: Date(),
            weight: nil,
            bodyFatPercentage: 21.5,
            leanBodyMass: nil
        )

        let samples = input.makeSamples()

        #expect(samples.count == 1)
        #expect(samples[0].sampleType == HKQuantityType(.bodyFatPercentage))
        #expect(samples[0].quantity.doubleValue(for: .percent()) == 0.215)
    }
}
