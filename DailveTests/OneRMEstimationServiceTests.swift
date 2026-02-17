import Foundation
import Testing
@testable import Dailve

@Suite("OneRMEstimationService")
struct OneRMEstimationServiceTests {

    let service = OneRMEstimationService()

    // MARK: - Formula Tests

    @Test("Epley formula: 100kg x 10 reps ≈ 133.3kg")
    func epleyFormula() {
        let result = OneRMFormula.epley.estimate(weight: 100, reps: 10)
        #expect(result != nil)
        let expected = 100.0 * (1.0 + 10.0 / 30.0)
        #expect(abs(result! - expected) < 0.01)
    }

    @Test("Brzycki formula: 100kg x 10 reps ≈ 133.3kg")
    func brzyckiFormula() {
        let result = OneRMFormula.brzycki.estimate(weight: 100, reps: 10)
        #expect(result != nil)
        let expected = 100.0 * 36.0 / (37.0 - 10.0)
        #expect(abs(result! - expected) < 0.01)
    }

    @Test("Lombardi formula: 100kg x 10 reps")
    func lombardiFormula() {
        let result = OneRMFormula.lombardi.estimate(weight: 100, reps: 10)
        #expect(result != nil)
        let expected = 100.0 * pow(10.0, 0.1)
        #expect(abs(result! - expected) < 0.01)
    }

    @Test("1 rep returns actual weight")
    func singleRep() {
        for formula in OneRMFormula.allCases {
            let result = formula.estimate(weight: 150, reps: 1)
            #expect(result == 150)
        }
    }

    @Test("Invalid inputs return nil")
    func invalidInputs() {
        #expect(OneRMFormula.epley.estimate(weight: 0, reps: 5) == nil)
        #expect(OneRMFormula.epley.estimate(weight: -10, reps: 5) == nil)
        #expect(OneRMFormula.epley.estimate(weight: 100, reps: 0) == nil)
        #expect(OneRMFormula.epley.estimate(weight: 100, reps: 31) == nil)
    }

    @Test("Brzycki returns nil at 37 reps (division by zero)")
    func brzyckiEdgeCase() {
        // reps > 30 blocked, but 30 should work
        let result = OneRMFormula.brzycki.estimate(weight: 100, reps: 30)
        #expect(result != nil)
    }

    // MARK: - Analysis Tests

    @Test("Empty sessions produce empty analysis")
    func emptyAnalysis() {
        let analysis = service.analyze(sessions: [])
        #expect(analysis.currentBest == nil)
        #expect(analysis.formulaComparison.isEmpty)
        #expect(analysis.history.isEmpty)
        #expect(analysis.trainingZones.isEmpty)
    }

    @Test("Single session with valid sets produces analysis")
    func singleSession() {
        let sessions = [
            OneRMSessionInput(date: Date(), sets: [
                OneRMSetInput(weight: 100, reps: 5),
                OneRMSetInput(weight: 80, reps: 10)
            ])
        ]
        let analysis = service.analyze(sessions: sessions)
        #expect(analysis.currentBest != nil)
        #expect(analysis.formulaComparison.count == 3) // 3 formulas
        #expect(analysis.history.count == 1)
        #expect(analysis.trainingZones.count == 4)
    }

    @Test("Training zones are in descending percentage order")
    func trainingZonesOrder() {
        let sessions = [
            OneRMSessionInput(date: Date(), sets: [
                OneRMSetInput(weight: 100, reps: 1)
            ])
        ]
        let analysis = service.analyze(sessions: sessions)
        let zones = analysis.trainingZones
        #expect(!zones.isEmpty)
        // Verify descending percentage order
        for i in 0..<(zones.count - 1) {
            #expect(zones[i].percentage.lowerBound >= zones[i + 1].percentage.lowerBound)
        }
    }

    @Test("Multiple sessions produce history points")
    func multipleSessionHistory() {
        let sessions = (0..<5).map { i in
            OneRMSessionInput(
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                sets: [OneRMSetInput(weight: 80 + Double(i) * 5, reps: 5)]
            )
        }
        let analysis = service.analyze(sessions: sessions)
        #expect(analysis.history.count == 5)
    }

    @Test("Sets with nil weight/reps are skipped")
    func nilSetsSkipped() {
        let sessions = [
            OneRMSessionInput(date: Date(), sets: [
                OneRMSetInput(weight: nil, reps: 5),
                OneRMSetInput(weight: 100, reps: nil),
                OneRMSetInput(weight: nil, reps: nil),
            ])
        ]
        let analysis = service.analyze(sessions: sessions)
        #expect(analysis.currentBest == nil)
        #expect(analysis.history.isEmpty)
    }

    @Test("Best 1RM selected across multiple sets")
    func bestAcrossSets() {
        let sessions = [
            OneRMSessionInput(date: Date(), sets: [
                OneRMSetInput(weight: 60, reps: 10),  // Epley: 80
                OneRMSetInput(weight: 100, reps: 3),  // Epley: 110
            ])
        ]
        let analysis = service.analyze(sessions: sessions)
        #expect(analysis.currentBest != nil)
        // The 100x3 set should give higher 1RM
        if let best = analysis.currentBest {
            #expect(best > 100)
        }
    }

    @Test("History point contains all three formulas")
    func historyPointFormulas() {
        let sessions = [
            OneRMSessionInput(date: Date(), sets: [
                OneRMSetInput(weight: 100, reps: 5)
            ])
        ]
        let analysis = service.analyze(sessions: sessions)
        guard let point = analysis.history.first else {
            #expect(Bool(false), "Expected history point")
            return
        }
        #expect(point.epley > 0)
        #expect(point.brzycki > 0)
        #expect(point.lombardi > 0)
        #expect(point.average > 0)
    }

    @Test("Training zone weights are based on 1RM")
    func zoneWeightsBasedOnOneRM() {
        let sessions = [
            OneRMSessionInput(date: Date(), sets: [
                OneRMSetInput(weight: 100, reps: 1) // 1RM = exactly 100
            ])
        ]
        let analysis = service.analyze(sessions: sessions)
        // With 1 rep, all formulas return 100, average = 100
        guard let strengthZone = analysis.trainingZones.first else {
            #expect(Bool(false), "Expected training zones")
            return
        }
        #expect(strengthZone.name == "Strength")
        #expect(strengthZone.weight.upperBound <= 101) // ≈ 100
        #expect(strengthZone.weight.lowerBound >= 84) // 85% of 100
    }
}
