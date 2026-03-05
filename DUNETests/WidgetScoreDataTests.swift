import Testing
import Foundation
@testable import DUNE

@Suite("WidgetScoreData")
struct WidgetScoreDataTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = WidgetScoreData(
            conditionScore: 82,
            conditionStatusRaw: "good",
            conditionMessage: "Solid recovery",
            readinessScore: 75,
            readinessStatusRaw: "moderate",
            readinessMessage: "Normal training is fine",
            wellnessScore: 68,
            wellnessStatusRaw: "fair",
            wellnessMessage: "Sleep needs attention",
            updatedAt: Date(timeIntervalSince1970: 1_709_640_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WidgetScoreData.self, from: data)

        #expect(decoded.conditionScore == 82)
        #expect(decoded.conditionStatusRaw == "good")
        #expect(decoded.conditionMessage == "Solid recovery")
        #expect(decoded.readinessScore == 75)
        #expect(decoded.readinessStatusRaw == "moderate")
        #expect(decoded.readinessMessage == "Normal training is fine")
        #expect(decoded.wellnessScore == 68)
        #expect(decoded.wellnessStatusRaw == "fair")
        #expect(decoded.wellnessMessage == "Sleep needs attention")
        #expect(decoded.updatedAt == Date(timeIntervalSince1970: 1_709_640_000))
    }

    @Test("Codable round-trip with all nil scores")
    func codableRoundTripNils() throws {
        let original = WidgetScoreData(
            conditionScore: nil,
            conditionStatusRaw: nil,
            conditionMessage: nil,
            readinessScore: nil,
            readinessStatusRaw: nil,
            readinessMessage: nil,
            wellnessScore: nil,
            wellnessStatusRaw: nil,
            wellnessMessage: nil,
            updatedAt: Date(timeIntervalSince1970: 1_709_640_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WidgetScoreData.self, from: data)

        #expect(decoded.conditionScore == nil)
        #expect(decoded.readinessScore == nil)
        #expect(decoded.wellnessScore == nil)
    }

    @Test("Partial scores preserve existing values")
    func partialScorePreservation() throws {
        let data = WidgetScoreData(
            conditionScore: 82,
            conditionStatusRaw: "good",
            conditionMessage: "test",
            readinessScore: nil,
            readinessStatusRaw: nil,
            readinessMessage: nil,
            wellnessScore: 90,
            wellnessStatusRaw: "excellent",
            wellnessMessage: "great",
            updatedAt: Date()
        )

        #expect(data.conditionScore == 82)
        #expect(data.readinessScore == nil)
        #expect(data.wellnessScore == 90)
    }

    @Test("App group ID is correct")
    func appGroupID() {
        #expect(WidgetScoreData.appGroupID == "group.com.raftel.dailve")
    }

    @Test("UserDefaults key is stable")
    func userDefaultsKey() {
        #expect(WidgetScoreData.userDefaultsKey == "widget_score_data")
    }
}
