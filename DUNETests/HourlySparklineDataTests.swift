import Foundation
import Testing
@testable import DUNE

@Suite("HourlySparklineData Tests")
struct HourlySparklineDataTests {

    // MARK: - DeltaDirection

    @Test("Delta direction is .up when delta >= threshold")
    func deltaDirectionUp() {
        let data = HourlySparklineData(
            points: [
                .init(hour: 8, score: 50),
                .init(hour: 9, score: 55)
            ],
            currentScore: 55,
            previousScore: 50
        )
        #expect(data.deltaDirection == .up)
        #expect(data.delta == 5)
    }

    @Test("Delta direction is .down when delta <= -threshold")
    func deltaDirectionDown() {
        let data = HourlySparklineData(
            points: [
                .init(hour: 8, score: 60),
                .init(hour: 9, score: 52)
            ],
            currentScore: 52,
            previousScore: 60
        )
        #expect(data.deltaDirection == .down)
        #expect(data.delta == -8)
    }

    @Test("Delta direction is .stable when |delta| < threshold")
    func deltaDirectionStable() {
        let data = HourlySparklineData(
            points: [
                .init(hour: 8, score: 50),
                .init(hour: 9, score: 51)
            ],
            currentScore: 51,
            previousScore: 50
        )
        #expect(data.deltaDirection == .stable)
        #expect(data.delta == 1)
    }

    @Test("Delta is 0 when no previous score")
    func deltaZeroWhenNoPrevious() {
        let data = HourlySparklineData(
            points: [.init(hour: 9, score: 65)],
            currentScore: 65,
            previousScore: nil
        )
        #expect(data.delta == 0)
        #expect(data.deltaDirection == .stable)
    }

    @Test("Empty sparkline data has no points")
    func emptySparkline() {
        let data = HourlySparklineData.empty
        #expect(data.points.isEmpty)
        #expect(data.currentScore == 0)
        #expect(data.deltaDirection == .stable)
    }

    // MARK: - ScoreType

    @Test("ScoreType cases exist")
    func scoreTypeCases() {
        let types: [ScoreType] = [.condition, .wellness, .readiness]
        #expect(types.count == 3)
    }
}
