import Testing
@testable import DUNEWatch

@Suite("Cardio distance milestones")
struct CardioDistanceMilestoneTests {
    @Test("One kilometer boundary is inclusive")
    func boundary() {
        #expect(CardioDistanceMilestone.reached(distanceMeters: 999.9, after: 0) == nil)
        #expect(CardioDistanceMilestone.reached(distanceMeters: 1_000, after: 0) == 1)
    }

    @Test("Repeated and rolled-back samples do not repeat an announced kilometer")
    func duplicateAndRollback() {
        #expect(CardioDistanceMilestone.reached(distanceMeters: 1_250, after: 1) == nil)
        #expect(CardioDistanceMilestone.reached(distanceMeters: 990, after: 1) == nil)
        #expect(CardioDistanceMilestone.reached(distanceMeters: 2_001, after: 1) == 2)
    }

    @Test("A large distance update announces the latest crossed kilometer once")
    func jump() {
        #expect(CardioDistanceMilestone.reached(distanceMeters: 3_010, after: 0) == 3)
    }

    @Test("Invalid samples are ignored")
    func invalid() {
        #expect(CardioDistanceMilestone.reached(distanceMeters: .nan, after: 0) == nil)
        #expect(CardioDistanceMilestone.reached(distanceMeters: -.infinity, after: 0) == nil)
        #expect(CardioDistanceMilestone.reached(distanceMeters: -1, after: 0) == nil)
        #expect(CardioDistanceMilestone.reached(distanceMeters: 500_000, after: 0) == nil)
    }
}
