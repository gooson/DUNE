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
                .init(index: 0, hour: 8, score: 50),
                .init(index: 1, hour: 9, score: 55)
            ],
            currentScore: 55,
            previousScore: 50,
            includesYesterday: false
        )
        #expect(data.deltaDirection == .up)
        #expect(data.delta == 5)
    }

    @Test("Delta direction is .down when delta <= -threshold")
    func deltaDirectionDown() {
        let data = HourlySparklineData(
            points: [
                .init(index: 0, hour: 8, score: 60),
                .init(index: 1, hour: 9, score: 52)
            ],
            currentScore: 52,
            previousScore: 60,
            includesYesterday: false
        )
        #expect(data.deltaDirection == .down)
        #expect(data.delta == -8)
    }

    @Test("Delta direction is .stable when |delta| < threshold")
    func deltaDirectionStable() {
        let data = HourlySparklineData(
            points: [
                .init(index: 0, hour: 8, score: 50),
                .init(index: 1, hour: 9, score: 51)
            ],
            currentScore: 51,
            previousScore: 50,
            includesYesterday: false
        )
        #expect(data.deltaDirection == .stable)
        #expect(data.delta == 1)
    }

    @Test("Delta is 0 when no previous score")
    func deltaZeroWhenNoPrevious() {
        let data = HourlySparklineData(
            points: [.init(index: 0, hour: 9, score: 65)],
            currentScore: 65,
            previousScore: nil,
            includesYesterday: false
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
        #expect(data.includesYesterday == false)
    }

    // MARK: - includesYesterday

    @Test("includesYesterday flag is preserved")
    func includesYesterdayFlag() {
        let data = HourlySparklineData(
            points: [
                .init(index: 0, hour: 22, score: 60),
                .init(index: 1, hour: 23, score: 58),
                .init(index: 2, hour: 0, score: 55),
                .init(index: 3, hour: 1, score: 57)
            ],
            currentScore: 57,
            previousScore: 55,
            includesYesterday: true
        )
        #expect(data.includesYesterday == true)
        #expect(data.points.count == 4)
        #expect(data.delta == 2)
        #expect(data.deltaDirection == .stable) // |2| == threshold, still stable
    }

    // MARK: - HourlyPoint identity

    @Test("HourlyPoint uses index as Identifiable id")
    func hourlyPointIdentity() {
        let p1 = HourlySparklineData.HourlyPoint(index: 0, hour: 23, score: 50)
        let p2 = HourlySparklineData.HourlyPoint(index: 1, hour: 0, score: 55)
        #expect(p1.id == 0)
        #expect(p2.id == 1)
        #expect(p1.id != p2.id)
    }

    // MARK: - nonEmptyOrNil

    @Test("nonEmptyOrNil returns nil for empty")
    func nonEmptyOrNilEmpty() {
        #expect(HourlySparklineData.empty.nonEmptyOrNil == nil)
    }

    @Test("nonEmptyOrNil returns self for non-empty")
    func nonEmptyOrNilNonEmpty() {
        let data = HourlySparklineData(
            points: [.init(index: 0, hour: 9, score: 65)],
            currentScore: 65,
            previousScore: nil,
            includesYesterday: false
        )
        #expect(data.nonEmptyOrNil != nil)
    }

    // MARK: - ScoreType

    @Test("ScoreType cases exist")
    func scoreTypeCases() {
        let types: [ScoreType] = [.condition, .wellness, .readiness]
        #expect(types.count == 3)
    }
}
