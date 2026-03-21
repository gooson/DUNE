import Testing
@testable import DUNE

@Suite("WhatsNewManager")
struct WhatsNewManagerTests {
    @Test("JSON parsing loads 0.2.0 release with all features")
    func jsonParsingLoads020Release() {
        let manager = WhatsNewManager.shared

        let release = manager.currentRelease(for: "0.2.0")

        #expect(release != nil)
        #expect(release?.features.count == 12)
    }

    @Test("Feature IDs match expected set")
    func featureIDsMatchExpectedSet() {
        let manager = WhatsNewManager.shared
        let release = manager.currentRelease(for: "0.2.0")!

        let ids = Set(release.features.map(\.id))
        let expected: Set<String> = [
            "widgets", "weather", "sleepDebt",
            "notifications", "trainingReadiness",
            "habits", "themes", "watchQuickStart",
            "cardioLiveTracking", "coachingInsights",
            "localization", "airQuality"
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

    @Test("JSON parsing loads 0.4.0 release with all features")
    func jsonParsingLoads040Release() {
        let manager = WhatsNewManager.shared

        let release = manager.currentRelease(for: "0.4.0")

        #expect(release != nil)
        #expect(release?.features.count == 7)
    }

    @Test("0.4.0 feature IDs match expected set")
    func featureIDsMatch040() {
        let manager = WhatsNewManager.shared
        let release = manager.currentRelease(for: "0.4.0")!

        let ids = Set(release.features.map(\.id))
        let expected: Set<String> = [
            "setLevelRPE", "stairClimber",
            "cardioFitness", "watchCardioUX",
            "workoutRewards", "sleepDeficit", "lifeTabUpgrade"
        ]
        #expect(ids == expected)
    }

    @Test("0.4.0 feature localization keys are non-empty")
    func featureLocalizationKeysNonEmpty040() {
        let manager = WhatsNewManager.shared
        let release = manager.currentRelease(for: "0.4.0")!

        for feature in release.features {
            #expect(!feature.titleKey.isEmpty, "titleKey should not be empty for \(feature.id)")
            #expect(!feature.summaryKey.isEmpty, "summaryKey should not be empty for \(feature.id)")
            #expect(!feature.symbolName.isEmpty, "symbolName should not be empty for \(feature.id)")
        }
    }

    @Test("JSON parsing loads 0.5.0 release with all features")
    func jsonParsingLoads050Release() {
        let manager = WhatsNewManager.shared

        let release = manager.currentRelease(for: "0.5.0")

        #expect(release != nil)
        #expect(release?.features.count == 7)
    }

    @Test("0.5.0 feature IDs match expected set")
    func featureIDsMatch050() {
        let manager = WhatsNewManager.shared
        let release = manager.currentRelease(for: "0.5.0")!

        let ids = Set(release.features.map(\.id))
        let expected: Set<String> = [
            "postureAssessment", "morningBriefing",
            "rpeTrend", "muscleMap3DOverhaul",
            "watchExerciseReorder", "hourlyCondition", "templateNudge"
        ]
        #expect(ids == expected)
    }

    @Test("0.5.0 feature localization keys are non-empty")
    func featureLocalizationKeysNonEmpty050() {
        let manager = WhatsNewManager.shared
        let release = manager.currentRelease(for: "0.5.0")!

        for feature in release.features {
            #expect(!feature.titleKey.isEmpty, "titleKey should not be empty for \(feature.id)")
            #expect(!feature.summaryKey.isEmpty, "summaryKey should not be empty for \(feature.id)")
            #expect(!feature.symbolName.isEmpty, "symbolName should not be empty for \(feature.id)")
        }
    }

    // MARK: - Screenshot Asset Tests

    @Test("screenshotAsset is parsed for features that have it")
    func screenshotAssetParsed() {
        let manager = WhatsNewManager.shared
        let release = manager.currentRelease(for: "0.5.0")!

        let posture = release.features.first { $0.id == "postureAssessment" }
        #expect(posture?.screenshotAsset == "WhatsNew/0.5.0/postureAssessment")
        #expect(posture?.screenshotAsset != nil)
    }

    @Test("screenshotAsset is nil for features without it")
    func screenshotAssetNilWhenMissing() {
        let manager = WhatsNewManager.shared
        let release = manager.currentRelease(for: "0.5.0")!

        let muscleMap = release.features.first { $0.id == "muscleMap3DOverhaul" }
        #expect(muscleMap?.screenshotAsset == nil)
    }

    @Test("Older versions have no screenshotAsset on any feature")
    func olderVersionsNoScreenshots() {
        let manager = WhatsNewManager.shared
        let release = manager.currentRelease(for: "0.2.0")!

        for feature in release.features {
            #expect(feature.screenshotAsset == nil, "Feature \(feature.id) should not have screenshotAsset")
        }
    }

    @Test("WhatsNewFeatureItem init with screenshotAsset")
    func featureItemInitWithScreenshot() {
        let feature = WhatsNewFeatureItem(
            id: "test",
            titleKey: "Test",
            summaryKey: "Test summary",
            symbolName: "star",
            area: .today,
            screenshotAsset: "WhatsNew/1.0.0/test"
        )

        #expect(feature.screenshotAsset != nil)
        #expect(feature.screenshotAsset == "WhatsNew/1.0.0/test")
    }

    @Test("WhatsNewFeatureItem init without screenshotAsset defaults to nil")
    func featureItemInitWithoutScreenshot() {
        let feature = WhatsNewFeatureItem(
            id: "test",
            titleKey: "Test",
            summaryKey: "Test summary",
            symbolName: "star",
            area: .today
        )

        #expect(feature.screenshotAsset == nil)
    }

    @Test("All five releases are loaded from per-version JSON files")
    func allReleasesLoaded() {
        let manager = WhatsNewManager.shared
        let releases = manager.orderedReleases()

        #expect(releases.count == 5)

        let versions = releases.map(\.version)
        #expect(versions.contains("0.1.0"))
        #expect(versions.contains("0.2.0"))
        #expect(versions.contains("0.3.0"))
        #expect(versions.contains("0.4.0"))
        #expect(versions.contains("0.5.0"))
    }
}
