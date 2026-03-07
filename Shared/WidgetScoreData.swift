import Foundation

/// Data shared between the main app and the widget extension via an App Group file.
struct WidgetScoreData: Codable, Sendable {
    var conditionScore: Int?
    var conditionStatusRaw: String?
    var conditionMessage: String?

    var readinessScore: Int?
    var readinessStatusRaw: String?
    var readinessMessage: String?

    var wellnessScore: Int?
    var wellnessStatusRaw: String?
    var wellnessMessage: String?

    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case conditionScore, conditionStatusRaw, conditionMessage
        case readinessScore, readinessStatusRaw, readinessMessage
        case wellnessScore, wellnessStatusRaw, wellnessMessage
        case updatedAt
    }

    static let userDefaultsKey = "com.raftel.dailve.widget_score_data"
    static let appGroupID = "group.com.raftel.dailve"
    static let fileName = "widget-score-data.json"

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    static func sharedContainerURL(
        containerURLProvider: (String) -> URL? = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    ) -> URL? {
        containerURLProvider(appGroupID)
    }

    static func sharedFileURL(
        containerURLProvider: (String) -> URL? = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    ) -> URL? {
        sharedContainerURL(containerURLProvider: containerURLProvider)?
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func sharedDefaults(
        containerURLProvider: (String) -> URL? = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        },
        userDefaultsProvider: (String) -> UserDefaults? = {
            UserDefaults(suiteName: $0)
        }
    ) -> UserDefaults? {
        guard containerURLProvider(appGroupID) != nil else { return nil }
        return userDefaultsProvider(appGroupID)
    }

    static func loadSharedData(
        containerURLProvider: (String) -> URL? = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        },
        userDefaultsProvider: (String) -> UserDefaults? = {
            UserDefaults(suiteName: $0)
        }
    ) -> WidgetScoreData? {
        let decoder = makeDecoder()

        if let fileURL = sharedFileURL(containerURLProvider: containerURLProvider),
           let jsonData = try? Data(contentsOf: fileURL) {
            if let data = try? decoder.decode(WidgetScoreData.self, from: jsonData) {
                return data
            }
            try? FileManager.default.removeItem(at: fileURL)
        }

        guard let defaults = sharedDefaults(
            containerURLProvider: containerURLProvider,
            userDefaultsProvider: userDefaultsProvider
        ) else {
            return nil
        }
        guard let legacyData = defaults.data(forKey: userDefaultsKey) else { return nil }
        guard let decoded = try? decoder.decode(WidgetScoreData.self, from: legacyData) else {
            defaults.removeObject(forKey: userDefaultsKey)
            return nil
        }

        if let fileURL = sharedFileURL(containerURLProvider: containerURLProvider),
           let encoded = try? makeEncoder().encode(decoded),
           (try? encoded.write(to: fileURL, options: .atomic)) != nil {
            defaults.removeObject(forKey: userDefaultsKey)
        }

        return decoded
    }

    static func saveSharedData(
        _ data: WidgetScoreData,
        containerURLProvider: (String) -> URL? = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    ) throws {
        guard let fileURL = sharedFileURL(containerURLProvider: containerURLProvider) else { return }
        try makeEncoder().encode(data).write(to: fileURL, options: .atomic)
    }
}
