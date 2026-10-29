import Foundation
import Testing
@testable import DUNE

@Suite("CardioAtlasProgress")
struct CardioAtlasProgressTests {
    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Corrupt finite extremes cannot overflow totals or duration formatting")
    func finiteExtremes() throws {
        let invalid = session("huge", .running, day: 0, duration: .greatestFiniteMagnitude, distance: 1_000)
        #expect(CardioAtlasProgress.calculate(sessions: [invalid], currentSessionID: invalid.id) == nil)
        let valid = session("actual-time", .stairClimbing, day: 0, duration: 600, distance: .greatestFiniteMagnitude)
        let progress = try #require(CardioAtlasProgress.calculate(sessions: [valid], currentSessionID: valid.id,
                                                               durationGoalSeconds: .greatestFiniteMagnitude))
        #expect(progress.journey.kind == .durationSeconds)
        #expect(progress.journey.total == 600)
        #expect(progress.journey.target == 10_800)
    }

    @Test("Editing a goal preserves actual totals and earned achievements")
    func goalEdit() throws {
        let recorded = session("recorded", .running, day: 0, duration: 1_800, distance: 5_000)
        let original = try #require(CardioAtlasProgress.calculate(sessions: [recorded], currentSessionID: recorded.id))
        let changed = original.updatingJourneyGoal(distanceMeters: 10_000, durationSeconds: 600)
        #expect(changed.journey.target == 10_000)
        #expect(changed.journey.total == original.journey.total)
        #expect(changed.achievements == original.achievements)
        #expect(changed.sessionCount == original.sessionCount)
        #expect(original.updatingJourneyGoal(distanceMeters: .nan, durationSeconds: 600).journey.target == 20_000)
    }

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

    @Test("Session count awards continue every hundred with the next milestone always available",
          arguments: [99, 100, 101, 199, 200, 201, 299, 300, 350, 1_000, 1_001])
    func continuingCountMilestones(count: Int) throws {
        let sessions = countSessions(count)

        let progress = try #require(CardioAtlasProgress.calculate(
            sessions: sessions, currentSessionID: "s\(count)"
        ))

        let base = [1, 5, 10, 20, 50, 100]
        let later = count >= 200 ? Array(stride(from: 200, through: count, by: 100)) : []
        let expectedAwards = (base.filter { $0 <= count } + later).map(Double.init)
        let countAwards = progress.achievements.filter { $0.kind == .sessionCount }
        let nextThreshold = base.first { $0 > count } ?? ((count / 100) + 1) * 100
        let next = try #require(progress.nextAchievements.first { $0.kind == .sessionCount })

        #expect(progress.sessionCount == count)
        #expect(countAwards.map(\.threshold) == expectedAwards)
        #expect(next.threshold == Double(nextThreshold))
        #expect(next.currentValue == Double(count))
        #expect(next.fraction == Double(count) / Double(nextThreshold))
    }

    @Test("Original count milestones retain their IDs and first-crossing dates")
    func originalCountMilestoneContracts() throws {
        let sessions = countSessions(100)
        let progress = try #require(CardioAtlasProgress.calculate(
            sessions: sessions, currentSessionID: "s100"
        ))

        for threshold in [1, 5, 10, 20, 50, 100] {
            let award = try #require(progress.achievements.first {
                $0.kind == .sessionCount && $0.threshold == Double(threshold)
            })
            #expect(award.id == "running-sessionCount-\(threshold)")
            #expect(award.awardedSessionID == "s\(threshold)")
            #expect(award.awardedAt == sessions[threshold - 1].date)
            #expect(award.achievedValue == Double(threshold))
        }
    }

    @Test("A hundred-count award belongs to exactly its chronological crossing", arguments: [200, 300])
    func countMilestoneFirstCrossing(threshold: Int) throws {
        let sessions = countSessions(threshold + 1)
        let atCrossing = try #require(CardioAtlasProgress.calculate(
            sessions: sessions, currentSessionID: "s\(threshold)"
        ))
        let afterCrossing = try #require(CardioAtlasProgress.calculate(
            sessions: sessions, currentSessionID: "s\(threshold + 1)"
        ))
        let award = try #require(atCrossing.achievements.first {
            $0.kind == .sessionCount && $0.threshold == Double(threshold)
        })

        #expect(award.id == "running-sessionCount-\(threshold)")
        #expect(award.awardedSessionID == "s\(threshold)")
        #expect(award.awardedAt == sessions[threshold - 1].date)
        #expect(award.achievedValue == Double(threshold))
        #expect(atCrossing.earnedInCurrentSession.contains { $0.id == award.id })
        #expect(afterCrossing.achievements.first { $0.id == award.id } == award)
        #expect(!afterCrossing.earnedInCurrentSession.contains { $0.id == award.id })
    }

    @Test("Reordered duplicates, unrelated activities, and invalid rows do not advance count awards")
    func countIgnoresUnrelatedRows() throws {
        let sessions = countSessions(200)
        let unrelated = (1...20).map { index in
            session("cycling\(index)", .cycling, day: index, duration: 600, distance: 1_000)
        }
        let invalid = [
            session("zero", .running, day: 50, duration: 0, distance: 1_000),
            session("nan", .running, day: 100, duration: .nan, distance: 1_000),
        ]
        let source = Array(sessions.reversed()) + unrelated + invalid + [sessions[0], sessions[99], sessions[199]]

        let progress = try #require(CardioAtlasProgress.calculate(
            sessions: source, currentSessionID: "s200"
        ))
        let award = try #require(progress.achievements.first {
            $0.kind == .sessionCount && $0.threshold == 200
        })

        #expect(progress.sessionCount == 200)
        #expect(award.awardedSessionID == "s200")
        #expect(award.awardedAt == sessions[199].date)
        #expect(progress.achievements.filter { $0.kind == .sessionCount && $0.threshold == 200 }.count == 1)
        #expect(progress.nextAchievements.first { $0.kind == .sessionCount }?.threshold == 300)
    }

    @Test("A historical current workout excludes later hundred-count awards")
    func historicalCountStopsAtCurrent() throws {
        let sessions = countSessions(300)

        let progress = try #require(CardioAtlasProgress.calculate(
            sessions: Array(sessions.reversed()), currentSessionID: "s199"
        ))

        #expect(progress.sessionCount == 199)
        #expect(!progress.achievements.contains { $0.kind == .sessionCount && $0.threshold == 200 })
        #expect(progress.nextAchievements.first { $0.kind == .sessionCount }?.threshold == 200)
        #expect(progress.nextAchievements.first { $0.kind == .sessionCount }?.currentValue == 199)
    }

    @Test("Deleting a workout before the 200th retracts that milestone")
    func deletionRetractsCountMilestone() throws {
        let sessions = countSessions(200)
        let reduced = sessions.filter { $0.id != "s50" }

        let before = try #require(CardioAtlasProgress.calculate(
            sessions: sessions, currentSessionID: "s200"
        ))
        let after = try #require(CardioAtlasProgress.calculate(
            sessions: reduced, currentSessionID: "s200"
        ))
        let next = try #require(after.nextAchievements.first { $0.kind == .sessionCount })

        #expect(before.achievements.contains { $0.kind == .sessionCount && $0.threshold == 200 })
        #expect(after.sessionCount == 199)
        #expect(!after.achievements.contains { $0.kind == .sessionCount && $0.threshold == 200 })
        #expect(!after.earnedInCurrentSession.contains { $0.kind == .sessionCount && $0.threshold == 200 })
        #expect(next.threshold == 200)
        #expect(next.currentValue == 199)
        #expect(next.fraction == 199.0 / 200)
    }

    private func countSessions(_ count: Int) -> [CardioAtlasSession] {
        (1...count).map { index in
            session("s\(index)", .running, day: index, duration: 600, distance: 1_000)
        }
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
