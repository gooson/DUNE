import Foundation
import Testing
@testable import DUNEWatch

@Suite("WorkoutElapsedTime")
struct WorkoutElapsedTimeTests {
    @Test("Elapsed time without pauses uses wall-clock duration")
    func elapsedWithoutPause() {
        let now = Date()
        let start = now.addingTimeInterval(-300)

        let elapsed = WorkoutElapsedTime.activeElapsedTime(
            startDate: start,
            pausedDuration: 0,
            pauseStart: nil,
            isPaused: false,
            now: now
        )

        #expect(elapsed == 300)
    }

    @Test("Elapsed time excludes accumulated and ongoing pause durations")
    func elapsedExcludesPauseDurations() {
        let now = Date()
        let start = now.addingTimeInterval(-600)
        let currentPauseStart = now.addingTimeInterval(-30)

        let elapsed = WorkoutElapsedTime.activeElapsedTime(
            startDate: start,
            pausedDuration: 120,
            pauseStart: currentPauseStart,
            isPaused: true,
            now: now
        )

        #expect(elapsed == 450)
    }

    @Test("Elapsed time never returns a negative value")
    func elapsedClampedToZero() {
        let now = Date()
        let start = now.addingTimeInterval(60)

        let elapsed = WorkoutElapsedTime.activeElapsedTime(
            startDate: start,
            pausedDuration: 0,
            pauseStart: nil,
            isPaused: false,
            now: now
        )

        #expect(elapsed == 0)
    }
}
