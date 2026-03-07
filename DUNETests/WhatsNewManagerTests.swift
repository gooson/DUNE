import Testing
@testable import DUNE

@Suite("WhatsNewManager")
struct WhatsNewManagerTests {
    @Test("JSON parsing loads 0.2.0 release with all features")
    func jsonParsingLoads020Release() {
        let manager = WhatsNewManager.shared

        let release = manager.currentRelease(for: "0.2.0")

        #expect(release != nil)
        #expect(release?.features.count == 11)
    }

    @Test("Feature IDs match expected set")
    func featureIDsMatchExpectedSet() {
        let manager = WhatsNewManager.shared
        let release = manager.currentRelease(for: "0.2.0")!

        let ids = Set(release.features.map(\.id))
        let expected: Set<String> = [
            "widgets", "conditionScore", "weather", "sleepDebt",
            "notifications", "muscleMap", "trainingReadiness",
            "wellness", "habits", "themes", "watchQuickStart"
        ]
        #expect(ids == expected)
    }

    @Test("orderedReleases puts preferred version first")
    func orderedReleasesPreferredFirst() {
        let releases = [
            WhatsNewReleaseData(version: "0.1.0", introKey: "Old", features: []),
            WhatsNewReleaseData(version: "0.2.0", introKey: "New", features: [])
        ]
        let manager = WhatsNewManager(releases: releases)

        let ordered = manager.orderedReleases(preferredVersion: "0.2.0")

        #expect(ordered.first?.version == "0.2.0")
        #expect(ordered.count == 2)
    }

    @Test("orderedReleases returns all when no preferred version")
    func orderedReleasesNoPreference() {
        let releases = [
            WhatsNewReleaseData(version: "0.1.0", introKey: "Old", features: []),
            WhatsNewReleaseData(version: "0.2.0", introKey: "New", features: [])
        ]
        let manager = WhatsNewManager(releases: releases)

        let ordered = manager.orderedReleases()

        #expect(ordered.count == 2)
        #expect(ordered.first?.version == "0.1.0")
    }

    @Test("currentRelease returns nil for unknown version")
    func currentReleaseNilForUnknown() {
        let manager = WhatsNewManager(releases: [])

        #expect(manager.currentRelease(for: "99.0.0") == nil)
    }

    @Test("Empty JSON produces empty releases")
    func emptyReleasesOnBadJSON() {
        let manager = WhatsNewManager(releases: [])

        #expect(manager.orderedReleases().isEmpty)
    }

    @Test("Feature localization keys are non-empty")
    func featureLocalizationKeysNonEmpty() {
        let manager = WhatsNewManager.shared
        let release = manager.currentRelease(for: "0.2.0")!

        for feature in release.features {
            #expect(!feature.titleKey.isEmpty, "titleKey should not be empty for \(feature.id)")
            #expect(!feature.summaryKey.isEmpty, "summaryKey should not be empty for \(feature.id)")
            #expect(!feature.symbolName.isEmpty, "symbolName should not be empty for \(feature.id)")
        }
    }
}
