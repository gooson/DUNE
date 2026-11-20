import Foundation
import Testing
@testable import DUNE

@Suite("Machine level history plot")
@MainActor
struct CardioMachineLevelHistoryPlotTests {
    @Test("Unequal active intervals end at workout duration")
    func durationWeightedSteps() throws {
        let changes = [
            try #require(CardioMachineLevelChange(elapsedSeconds: 0, level: 3)),
            try #require(CardioMachineLevelChange(elapsedSeconds: 240, level: 6)),
            try #require(CardioMachineLevelChange(elapsedSeconds: 720, level: 8)),
            try #require(CardioMachineLevelChange(elapsedSeconds: 960, level: 4))
        ]
        let points = CardioMachineLevelHistoryView.plotPoints(changes: changes, duration: 1200)
        #expect(points.map(\.elapsed) == [0, 240, 720, 960, 1200])
        #expect(points.map(\.level) == [3, 6, 8, 4, 4])
    }

    @Test("Last level is not extended past the supplied end")
    func noInventedDuration() throws {
        let changes = [try #require(CardioMachineLevelChange(elapsedSeconds: 0, level: 3))]
        let points = CardioMachineLevelHistoryView.plotPoints(changes: changes, duration: 0)
        #expect(points.count == 1)
    }
}
