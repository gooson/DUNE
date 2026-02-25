import Foundation
import Testing
@testable import DUNE

@Suite("CloudKit Date Roundtrip Guards")
struct CloudKitDateRoundtripTests {
    private struct DatePayload: Codable {
        let date: Date
    }

    @Test("JSON date roundtrip keeps millisecond precision")
    func jsonDateRoundtripKeepsMilliseconds() throws {
        let original = Date(timeIntervalSince1970: 1_738_000_000.123_456)

        let data = try JSONEncoder().encode(DatePayload(date: original))
        let decoded = try JSONDecoder().decode(DatePayload.self, from: data)

        let drift = abs(decoded.date.timeIntervalSince1970 - original.timeIntervalSince1970)
        #expect(drift < 0.001)
    }

    @Test("Watch workout update date roundtrip preserves absolute instants")
    func watchWorkoutUpdateRoundtrip() throws {
        let start = Date(timeIntervalSince1970: 1_738_111_111.987)
        let end = Date(timeIntervalSince1970: 1_738_111_777.123)
        let update = WatchWorkoutUpdate(
            exerciseID: "bench_press",
            exerciseName: "Bench Press",
            completedSets: [
                WatchSetData(setNumber: 1, weight: 60, reps: 10, duration: nil, isCompleted: true)
            ],
            startTime: start,
            endTime: end,
            heartRateSamples: []
        )

        let data = try JSONEncoder().encode(update)
        let decoded = try JSONDecoder().decode(WatchWorkoutUpdate.self, from: data)

        #expect(abs(decoded.startTime.timeIntervalSince1970 - start.timeIntervalSince1970) < 0.001)
        #expect(abs((decoded.endTime ?? .distantPast).timeIntervalSince1970 - end.timeIntervalSince1970) < 0.001)
    }

    @Test("Date timezone rendering does not change stored absolute value")
    func timezoneRenderingDoesNotMutateDate() throws {
        let original = Date(timeIntervalSince1970: 1_738_222_222.555)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let utcString = formatter.string(from: original)

        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let seoulString = formatter.string(from: original)

        let parsedUTC = formatter.date(from: utcString)
        let parsedSeoul = formatter.date(from: seoulString)

        #expect(abs((parsedUTC ?? .distantPast).timeIntervalSince1970 - original.timeIntervalSince1970) < 0.001)
        #expect(abs((parsedSeoul ?? .distantPast).timeIntervalSince1970 - original.timeIntervalSince1970) < 0.001)
    }
}
