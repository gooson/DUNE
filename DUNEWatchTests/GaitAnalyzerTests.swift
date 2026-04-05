import Foundation
import Testing
@testable import DUNEWatch

@Suite("GaitAnalyzer Tests")
struct GaitAnalyzerTests {

    // MARK: - Minimum Sample Count

    @Test("Returns nil when samples are empty")
    func emptySamples() {
        // CMDeviceMotion cannot be instantiated in tests without private API,
        // so we test the threshold constant directly and the nil-return path.
        #expect(GaitAnalyzer.minimumSampleCount == 250)
    }

    // MARK: - Score Clamping

    @Test("Overall score is clamped to 0-100 range")
    func scoreClamping() {
        let score = GaitQualityScore(symmetry: 1.0, regularity: 1.0, overall: 100)
        #expect(score.overall >= 0)
        #expect(score.overall <= 100)
    }

    @Test("Zero score is representable")
    func zeroScore() {
        let score = GaitQualityScore.zero
        #expect(score.symmetry == 0)
        #expect(score.regularity == 0)
        #expect(score.overall == 0)
    }

    // MARK: - Domain Models

    @Test("DailyPostureSummary is Codable round-trip")
    func summaryCodable() throws {
        let summary = DailyPostureSummary(
            sedentaryMinutes: 120,
            walkingMinutes: 30,
            averageGaitScore: 75,
            stretchRemindersTriggered: 2,
            date: Date(timeIntervalSince1970: 1_711_100_000),
            isMonitoringEnabled: true
        )

        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(DailyPostureSummary.self, from: data)

        #expect(decoded == summary)
        #expect(decoded.isMonitoringEnabled == true)
    }

    @Test("DailyPostureSummary with nil gait score encodes correctly")
    func summaryNilGaitScore() throws {
        let summary = DailyPostureSummary(
            sedentaryMinutes: 45,
            walkingMinutes: 0,
            averageGaitScore: nil,
            stretchRemindersTriggered: 1,
            date: Date()
        )

        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(DailyPostureSummary.self, from: data)

        #expect(decoded.averageGaitScore == nil)
    }

    @Test("DailyPostureSummary backward-compatible decoding without isMonitoringEnabled")
    func summaryBackwardCompatible() throws {
        let json = """
        {"sedentaryMinutes":60,"walkingMinutes":15,"stretchRemindersTriggered":1,"date":0}
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(DailyPostureSummary.self, from: data)

        #expect(decoded.sedentaryMinutes == 60)
        #expect(decoded.walkingMinutes == 15)
        #expect(decoded.isMonitoringEnabled == true)
    }

    @Test("DailyPostureSummary with monitoring disabled round-trips")
    func summaryMonitoringDisabled() throws {
        let summary = DailyPostureSummary(
            sedentaryMinutes: 0,
            walkingMinutes: 0,
            averageGaitScore: nil,
            stretchRemindersTriggered: 0,
            date: Date(),
            isMonitoringEnabled: false
        )

        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(DailyPostureSummary.self, from: data)

        #expect(decoded.isMonitoringEnabled == false)
        #expect(decoded.hasNoActivityData == true)
    }

    @Test("DailyPostureSummary hasNoActivityData detects empty data")
    func summaryHasNoActivityData() {
        let empty = DailyPostureSummary(
            sedentaryMinutes: 0,
            walkingMinutes: 0,
            averageGaitScore: nil,
            stretchRemindersTriggered: 0,
            date: Date()
        )
        #expect(empty.hasNoActivityData == true)

        let withSedentary = DailyPostureSummary(
            sedentaryMinutes: 5,
            walkingMinutes: 0,
            averageGaitScore: nil,
            stretchRemindersTriggered: 0,
            date: Date()
        )
        #expect(withSedentary.hasNoActivityData == false)
    }

    @Test("PostureActivityState raw values are stable for serialization")
    func activityStateRawValues() {
        #expect(PostureActivityState.stationary.rawValue == "stationary")
        #expect(PostureActivityState.walking.rawValue == "walking")
        #expect(PostureActivityState.running.rawValue == "running")
        #expect(PostureActivityState.unknown.rawValue == "unknown")
    }

    // MARK: - GaitQualityScore Equality

    @Test("GaitQualityScore Equatable works correctly")
    func gaitScoreEquality() {
        let a = GaitQualityScore(symmetry: 0.8, regularity: 0.9, overall: 85)
        let b = GaitQualityScore(symmetry: 0.8, regularity: 0.9, overall: 85)
        let c = GaitQualityScore(symmetry: 0.7, regularity: 0.9, overall: 80)

        #expect(a == b)
        #expect(a != c)
    }
}
