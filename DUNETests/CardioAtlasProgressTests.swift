import Foundation
import Testing
@testable import DUNE

@Suite("CardioAtlasProgress")
struct CardioAtlasProgressTests {
    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Measured distance drives the journey across indoor and outdoor sessions")
    func distanceJourney() throws {
        let sessions = [
            session("outdoor", .running, day: 0, duration: 1_500, distance: 4_000, indoor: false),
            session("indoor", .running, day: 1, duration: 2_000, distance: 6_000, indoor: true),
            session("other", .cycling, day: 0, duration: 2_000, distance: 8_000),
            session("future", .running, day: 2, duration: 2_000, distance: 9_000),
        ]

        let progress = try #require(CardioAtlasProgress.calculate(
            sessions: sessions,
            currentSessionID: "indoor",
            distanceGoalMeters: 12_000
        ))

        #expect(progress.journey.kind == .distanceMeters)
        #expect(progress.journey.currentContribution == 6_000)
        #expect(progress.journey.total == 10_000)
        #expect(progress.journey.target == 12_000)
        #expect(progress.journey.fraction == 10.0 / 12.0)
        #expect(progress.sessionCount == 2)
        #expect(progress.earnedInCurrentSession.contains { $0.kind == .singleDistance })
        #expect(progress.achievements.first { $0.kind == .singleDistance }?.awardedSessionID == "indoor")
    }

    @Test("Missing and invalid distance use real duration without converting floors or steps")
    func durationFallback() throws {
        let sessions = [
            session("first", .stairClimbing, day: 0, duration: 1_200, distance: nil),
            session("current", .stairClimbing, day: 1, duration: 2_100, distance: .nan),
            session("badDistance", .stairClimbing, day: 2, duration: 600, distance: -.infinity),
        ]

        let progress = try #require(CardioAtlasProgress.calculate(
            sessions: sessions,
            currentSessionID: "current",
            durationGoalSeconds: 3_000
        ))

        #expect(progress.journey.kind == .durationSeconds)
        #expect(progress.journey.currentContribution == 2_100)
        #expect(progress.journey.total == 3_300)
        #expect(progress.journey.fraction == 1)
        #expect(progress.achievements.contains { $0.kind == .singleDuration })
        #expect(!progress.achievements.contains { $0.kind == .singleDistance })
    }

    @Test("Swim and row sessions can earn their measured distance threshold")
    func waterAndRowing() throws {
        for activity: WorkoutActivityType in [.swimming, .rowing] {
            let progress = try #require(CardioAtlasProgress.calculate(
                sessions: [session("one", activity, day: 0, duration: 900, distance: 1_000)],
                currentSessionID: "one"
            ))
            let award = try #require(progress.achievements.first { $0.kind == .singleDistance })
            #expect(award.threshold == 1_000)
            #expect(award.awardedSessionID == "one")
        }
    }

    @Test("An achievement belongs only to its first chronological threshold crossing")
    func firstAwardOnly() throws {
        let sessions = [
            session("z", .running, day: 0, duration: 1_000, distance: 5_000),
            session("a", .running, day: 0, duration: 2_000, distance: 6_000),
            session("later", .running, day: 1, duration: 2_000, distance: 8_000),
        ]

        let progress = try #require(CardioAtlasProgress.calculate(
            sessions: sessions,
            currentSessionID: "later"
        ))

        let distanceAwards = progress.achievements.filter { $0.kind == .singleDistance }
        #expect(distanceAwards.count == 1)
        #expect(distanceAwards.first?.awardedSessionID == "a")
        #expect(!progress.earnedInCurrentSession.contains { $0.kind == .singleDistance })
        #expect(progress.achievements.first { $0.kind == .sessionCount && $0.threshold == 1 }?.awardedSessionID == "a")
    }

    @Test("Stable IDs deduplicate reordered source rows and count milestones progress")
    func dedupAndCount() throws {
        let sessions = (1...5).map { index in
            session("s\(index)", .cycling, day: index, duration: 600, distance: 1_000)
        }
        let duplicate = sessions + [sessions[0], sessions[4]]

        let progress = try #require(CardioAtlasProgress.calculate(
            sessions: Array(duplicate.reversed()),
            currentSessionID: "s5"
        ))

        #expect(progress.sessionCount == 5)
        #expect(progress.journey.total == 5_000)
        #expect(progress.achievements.first { $0.kind == .sessionCount && $0.threshold == 5 }?.awardedSessionID == "s5")
        #expect(progress.nextAchievements.first { $0.kind == .sessionCount }?.threshold == 10)
        #expect(progress.nextAchievements.first { $0.kind == .sessionCount }?.currentValue == 5)
    }

    @Test("Invalid sessions and an absent current ID cannot create progress")
    func invalidSessions() throws {
        let valid = session("good", .running, day: 0, duration: 1_000, distance: 3_000)
        let invalid = [
            session("zero", .running, day: 0, duration: 0, distance: 8_000),
            session("negative", .running, day: 0, duration: -1, distance: 8_000),
            session("nan", .running, day: 0, duration: .nan, distance: 8_000),
        ]
        let progress = try #require(CardioAtlasProgress.calculate(
            sessions: [valid] + invalid,
            currentSessionID: "good",
            distanceGoalMeters: .infinity
        ))

        #expect(progress.journey.total == 3_000)
        #expect(progress.journey.target == 20_000)
        #expect(CardioAtlasProgress.calculate(sessions: [valid] + invalid, currentSessionID: "zero") == nil)
        #expect(CardioAtlasProgress.calculate(sessions: [valid], currentSessionID: "missing") == nil)
    }

    @Test("Removing a session recomputes awards and monthly active days")
    func deletionRecomputes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let currentDate = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 UTC
        let first = CardioAtlasSession(id: "first", activityType: .swimming, date: currentDate, duration: 600, distanceMeters: 1_000)
        let second = CardioAtlasSession(id: "second", activityType: .swimming, date: currentDate.addingTimeInterval(86_400), duration: 600, distanceMeters: 500)

        let before = try #require(CardioAtlasProgress.calculate(
            sessions: [first, second], currentSessionID: "second", calendar: calendar
        ))
        let after = try #require(CardioAtlasProgress.calculate(
            sessions: [second], currentSessionID: "second", calendar: calendar
        ))

        #expect(before.activeDaysInCurrentMonth == 2)
        #expect(after.activeDaysInCurrentMonth == 1)
        #expect(before.achievements.contains { $0.kind == .singleDistance })
        #expect(!after.achievements.contains { $0.kind == .singleDistance })
        #expect(after.nextAchievements.first { $0.kind == .singleDistance }?.currentValue == 500)
    }

    private func session(
        _ id: String,
        _ activity: WorkoutActivityType,
        day: Int,
        duration: TimeInterval,
        distance: Double?,
        indoor: Bool? = nil
    ) -> CardioAtlasSession {
        CardioAtlasSession(
            id: id,
            activityType: activity,
            date: self.day.addingTimeInterval(Double(day) * 86_400),
            duration: duration,
            distanceMeters: distance,
            isIndoor: indoor
        )
    }
}
