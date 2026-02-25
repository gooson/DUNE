import Foundation
import Testing
@testable import DUNE

@Suite("FatigueLevel")
struct FatigueLevelTests {

    @Test("from(normalizedScore:) maps boundary values correctly")
    func boundaryMapping() {
        #expect(FatigueLevel.from(normalizedScore: 0.0) == .fullyRecovered)
        #expect(FatigueLevel.from(normalizedScore: 0.04) == .fullyRecovered)
        #expect(FatigueLevel.from(normalizedScore: 0.05) == .wellRested)
        #expect(FatigueLevel.from(normalizedScore: 0.15) == .lightFatigue)
        #expect(FatigueLevel.from(normalizedScore: 0.25) == .mildFatigue)
        #expect(FatigueLevel.from(normalizedScore: 0.35) == .moderateFatigue)
        #expect(FatigueLevel.from(normalizedScore: 0.50) == .notableFatigue)
        #expect(FatigueLevel.from(normalizedScore: 0.65) == .highFatigue)
        #expect(FatigueLevel.from(normalizedScore: 0.75) == .veryHighFatigue)
        #expect(FatigueLevel.from(normalizedScore: 0.85) == .extremeFatigue)
        #expect(FatigueLevel.from(normalizedScore: 0.95) == .overtrained)
        #expect(FatigueLevel.from(normalizedScore: 1.0) == .overtrained)
    }

    @Test("from(normalizedScore:) clamps out-of-range values")
    func clampsOutOfRange() {
        #expect(FatigueLevel.from(normalizedScore: -0.5) == .fullyRecovered)
        #expect(FatigueLevel.from(normalizedScore: 1.5) == .overtrained)
    }

    @Test("from(normalizedScore:) handles NaN and Infinity")
    func handlesSpecialValues() {
        // Non-finite values fall back to safe default (fullyRecovered)
        #expect(FatigueLevel.from(normalizedScore: .nan) == .fullyRecovered)
        #expect(FatigueLevel.from(normalizedScore: .infinity) == .fullyRecovered)
        #expect(FatigueLevel.from(normalizedScore: -.infinity) == .fullyRecovered)
    }

    @Test("isTrainingRecommended for low levels")
    func trainingRecommended() {
        #expect(FatigueLevel.fullyRecovered.isTrainingRecommended == true)
        #expect(FatigueLevel.wellRested.isTrainingRecommended == true)
        #expect(FatigueLevel.lightFatigue.isTrainingRecommended == true)
        #expect(FatigueLevel.mildFatigue.isTrainingRecommended == true)
        #expect(FatigueLevel.moderateFatigue.isTrainingRecommended == false)
        // noData (rawValue=0) has no restriction — no data means no known fatigue
        #expect(FatigueLevel.noData.isTrainingRecommended == true)
    }

    @Test("isRestAdvised for high levels")
    func restAdvised() {
        #expect(FatigueLevel.veryHighFatigue.isRestAdvised == true)
        #expect(FatigueLevel.extremeFatigue.isRestAdvised == true)
        #expect(FatigueLevel.overtrained.isRestAdvised == true)
        #expect(FatigueLevel.highFatigue.isRestAdvised == false)
        #expect(FatigueLevel.fullyRecovered.isRestAdvised == false)
    }

    @Test("Comparable ordering")
    func comparableOrdering() {
        #expect(FatigueLevel.fullyRecovered < FatigueLevel.overtrained)
        #expect(FatigueLevel.noData < FatigueLevel.fullyRecovered)
        #expect(FatigueLevel.highFatigue > FatigueLevel.lightFatigue)
    }

    @Test("allCases has 11 members (noData + 10 levels)")
    func allCasesCount() {
        #expect(FatigueLevel.allCases.count == 11)
    }
}
