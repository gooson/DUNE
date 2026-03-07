import Foundation

enum WhatsNewArea: String, Codable, Hashable, Sendable {
    case today
    case activity
    case wellness
    case life
    case watch
    case settings

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = WhatsNewArea(rawValue: rawValue) ?? .today
    }
}

struct WhatsNewFeatureItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let titleKey: String
    let summaryKey: String
    let symbolName: String
    let area: WhatsNewArea
    let title: String
    let summary: String

    enum CodingKeys: String, CodingKey {
        case id, titleKey, summaryKey, symbolName, area
    }

    init(id: String, titleKey: String, summaryKey: String, symbolName: String, area: WhatsNewArea) {
        self.id = id
        self.titleKey = titleKey
        self.summaryKey = summaryKey
        self.symbolName = symbolName
        self.area = area
        self.title = String(localized: String.LocalizationValue(titleKey))
        self.summary = String(localized: String.LocalizationValue(summaryKey))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        titleKey = try container.decode(String.self, forKey: .titleKey)
        summaryKey = try container.decode(String.self, forKey: .summaryKey)
        symbolName = try container.decode(String.self, forKey: .symbolName)
        area = try container.decode(WhatsNewArea.self, forKey: .area)
        title = String(localized: String.LocalizationValue(titleKey))
        summary = String(localized: String.LocalizationValue(summaryKey))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(titleKey, forKey: .titleKey)
        try container.encode(summaryKey, forKey: .summaryKey)
        try container.encode(symbolName, forKey: .symbolName)
        try container.encode(area, forKey: .area)
    }
}

struct WhatsNewReleaseData: Codable, Identifiable, Hashable, Sendable {
    let version: String
    let introKey: String
    let features: [WhatsNewFeatureItem]
    let intro: String

    var id: String { version }

    enum CodingKeys: String, CodingKey {
        case version, introKey, features
    }

    init(version: String, introKey: String, features: [WhatsNewFeatureItem]) {
        self.version = version
        self.introKey = introKey
        self.features = features
        self.intro = String(localized: String.LocalizationValue(introKey))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        introKey = try container.decode(String.self, forKey: .introKey)
        features = try container.decode([WhatsNewFeatureItem].self, forKey: .features)
        intro = String(localized: String.LocalizationValue(introKey))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(introKey, forKey: .introKey)
        try container.encode(features, forKey: .features)
    }
}

struct WhatsNewCatalog: Codable, Sendable {
    let releases: [WhatsNewReleaseData]
}
