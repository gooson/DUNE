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
        #expect(WidgetScoreData.userDefaultsKey == "com.raftel.dailve.widget_score_data")
    }

    @Test("Shared file URL is nil when app group container is unavailable")
    func sharedFileURLRequiresContainer() {
        let fileURL = WidgetScoreData.sharedFileURL(
            containerURLProvider: { _ in nil }
        )

        #expect(fileURL == nil)
    }

    @Test("Shared file URL resolves inside app group container")
    func sharedFileURLResolvesInsideContainer() {
        let containerURL = URL(fileURLWithPath: "/tmp/widget-group", isDirectory: true)
        let fileURL = WidgetScoreData.sharedFileURL(
            containerURLProvider: { _ in containerURL }
        )

        #expect(fileURL != nil)
        #expect(fileURL?.deletingLastPathComponent() == containerURL)
        #expect(fileURL?.lastPathComponent == WidgetScoreData.fileName)
    }

    @Test("loadSharedData migrates legacy defaults into file storage")
    func loadSharedDataMigratesLegacyDefaultsIntoFile() throws {
        let suiteName = "WidgetScoreDataTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        let legacy = WidgetScoreData(
            conditionScore: 81,
            conditionStatusRaw: "good",
            conditionMessage: "Migrated",
            readinessScore: 72,
            readinessStatusRaw: "moderate",
            readinessMessage: "Steady",
            wellnessScore: 68,
            wellnessStatusRaw: "fair",
            wellnessMessage: "Needs rest",
            updatedAt: Date(timeIntervalSince1970: 1_709_640_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        defaults.set(try encoder.encode(legacy), forKey: WidgetScoreData.userDefaultsKey)

        let loaded = WidgetScoreData.loadSharedData(
            containerURLProvider: { _ in containerURL },
            userDefaultsProvider: { _ in defaults }
        )
        let fileURL = try #require(WidgetScoreData.sharedFileURL(
            containerURLProvider: { _ in containerURL }
        ))

        #expect(loaded?.conditionScore == legacy.conditionScore)
        #expect(loaded?.updatedAt == legacy.updatedAt)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        #expect(defaults.data(forKey: WidgetScoreData.userDefaultsKey) == nil)
    }

    @Test("loadSharedData prefers file storage without touching legacy defaults")
    func loadSharedDataPrefersFileWithoutLegacyLookup() throws {
        let suiteName = "WidgetScoreDataTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        let fileData = WidgetScoreData(
            conditionScore: 95,
            conditionStatusRaw: "excellent",
            conditionMessage: "From file",
            readinessScore: nil,
            readinessStatusRaw: nil,
            readinessMessage: nil,
            wellnessScore: nil,
            wellnessStatusRaw: nil,
            wellnessMessage: nil,
            updatedAt: Date(timeIntervalSince1970: 1_709_640_100)
        )
        let legacyData = WidgetScoreData(
            conditionScore: 10,
            conditionStatusRaw: "poor",
            conditionMessage: "Legacy",
            readinessScore: nil,
            readinessStatusRaw: nil,
            readinessMessage: nil,
            wellnessScore: nil,
            wellnessStatusRaw: nil,
            wellnessMessage: nil,
            updatedAt: Date(timeIntervalSince1970: 1_709_640_000)
        )

        let fileURL = try #require(WidgetScoreData.sharedFileURL(
            containerURLProvider: { _ in containerURL }
        ))
        try encoder.encode(fileData).write(to: fileURL, options: .atomic)
        defaults.set(try encoder.encode(legacyData), forKey: WidgetScoreData.userDefaultsKey)

        var didQueryLegacyDefaults = false
        let loaded = WidgetScoreData.loadSharedData(
            containerURLProvider: { _ in containerURL },
            userDefaultsProvider: { _ in
                didQueryLegacyDefaults = true
                return defaults
            }
        )

        #expect(loaded?.conditionScore == fileData.conditionScore)
        #expect(loaded?.updatedAt == fileData.updatedAt)
        #expect(didQueryLegacyDefaults == false)
        #expect(defaults.data(forKey: WidgetScoreData.userDefaultsKey) != nil)
    }

    @Test("saveSharedData writes a decodable shared file")
    func saveSharedDataWritesDecodableFile() throws {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        let original = WidgetScoreData(
            conditionScore: 77,
            conditionStatusRaw: "good",
            conditionMessage: "Saved",
            readinessScore: 71,
            readinessStatusRaw: "moderate",
            readinessMessage: "Okay",
            wellnessScore: 69,
            wellnessStatusRaw: "fair",
            wellnessMessage: "Decent",
            updatedAt: Date(timeIntervalSince1970: 1_709_640_200)
        )

        try WidgetScoreData.saveSharedData(
            original,
            containerURLProvider: { _ in containerURL }
        )

        let fileURL = try #require(WidgetScoreData.sharedFileURL(
            containerURLProvider: { _ in containerURL }
        ))
        let savedData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(WidgetScoreData.self, from: savedData)

        #expect(decoded.conditionScore == original.conditionScore)
        #expect(decoded.updatedAt == original.updatedAt)
    }
}
