import Foundation
import Testing
@testable import DUNE

@Suite("AppTheme")
struct AppThemeTests {
    @Test("Raw values are stable (persisted in UserDefaults)")
    func rawValuesStable() {
        #expect(AppTheme.desertWarm.rawValue == "desertWarm")
        #expect(AppTheme.oceanCool.rawValue == "oceanCool")
        #expect(AppTheme.forestGreen.rawValue == "forestGreen")
        #expect(AppTheme.sakuraCalm.rawValue == "sakuraCalm")
        #expect(AppTheme.arcticDawn.rawValue == "arcticDawn")
        #expect(AppTheme.solarPop.rawValue == "solarPop")
        #expect(AppTheme.shanksRed.rawValue == "shanksRed")
        #expect(AppTheme.hanok.rawValue == "hanok")
    }

    @Test("Codable round-trip preserves identity")
    func codableRoundTrip() throws {
        for theme in AppTheme.allCases {
            let data = try JSONEncoder().encode(theme)
            let decoded = try JSONDecoder().decode(AppTheme.self, from: data)
            #expect(decoded == theme)
        }
    }

    @Test("CaseIterable includes all themes")
    func allCases() {
        #expect(AppTheme.allCases.count == 8)
        #expect(AppTheme.allCases.contains(.desertWarm))
        #expect(AppTheme.allCases.contains(.oceanCool))
        #expect(AppTheme.allCases.contains(.forestGreen))
        #expect(AppTheme.allCases.contains(.sakuraCalm))
        #expect(AppTheme.allCases.contains(.arcticDawn))
        #expect(AppTheme.allCases.contains(.solarPop))
        #expect(AppTheme.allCases.contains(.shanksRed))
        #expect(AppTheme.allCases.contains(.hanok))
    }

    @Test("Init from unknown rawValue returns nil")
    func unknownRawValue() {
        #expect(AppTheme(rawValue: "neonPunk") == nil)
        #expect(AppTheme(rawValue: "") == nil)
    }

    @Test("Persisted rawValue resolver normalizes legacy artic aliases")
    func persistedRawValueResolver() {
        #expect(AppTheme.resolvedTheme(fromPersistedRawValue: "artic") == .arcticDawn)
        #expect(AppTheme.resolvedTheme(fromPersistedRawValue: "articDawn") == .arcticDawn)
        #expect(AppTheme.resolvedTheme(fromPersistedRawValue: " arcticDawn ") == .arcticDawn)
        #expect(AppTheme.normalizedRawValue(fromPersistedRawValue: "articDawn") == AppTheme.arcticDawn.rawValue)
    }

    @Test("Asset prefix mapping is stable for each theme")
    func assetPrefixMapping() {
        #expect(AppTheme.desertWarm.assetPrefix == nil)
        #expect(AppTheme.oceanCool.assetPrefix == "Ocean")
        #expect(AppTheme.forestGreen.assetPrefix == "Forest")
        #expect(AppTheme.sakuraCalm.assetPrefix == "Sakura")
        #expect(AppTheme.arcticDawn.assetPrefix == "Arctic")
        #expect(AppTheme.solarPop.assetPrefix == "Solar")
        #expect(AppTheme.shanksRed.assetPrefix == "Shanks")
        #expect(AppTheme.hanok.assetPrefix == "Hanok")
    }

    @Test("usesGlassBorder returns true for glass-border themes")
    func glassBorderThemes() {
        let glassThemes: [AppTheme] = [.sakuraCalm, .arcticDawn, .solarPop, .hanok, .shanksRed]
        let plainThemes: [AppTheme] = [.desertWarm, .oceanCool, .forestGreen]
        for theme in glassThemes {
            #expect(theme.usesGlassBorder == true)
        }
        for theme in plainThemes {
            #expect(theme.usesGlassBorder == false)
        }
    }

    @Test("Themed asset name resolution follows prefix convention")
    func themedAssetNameResolution() {
        #expect(
            AppTheme.desertWarm.themedAssetName(defaultAsset: "ScoreGood", variantSuffix: "ScoreGood")
                == "ScoreGood"
        )
        #expect(
            AppTheme.oceanCool.themedAssetName(defaultAsset: "ScoreGood", variantSuffix: "ScoreGood")
                == "OceanScoreGood"
        )
        #expect(
            AppTheme.forestGreen.themedAssetName(defaultAsset: "MetricHRV", variantSuffix: "MetricHRV")
                == "ForestMetricHRV"
        )
        #expect(
            AppTheme.sakuraCalm.themedAssetName(defaultAsset: "CardBackground", variantSuffix: "CardBackground")
                == "SakuraCardBackground"
        )
        #expect(
            AppTheme.arcticDawn.themedAssetName(defaultAsset: "ScoreWarning", variantSuffix: "ScoreWarning")
                == "ArcticScoreWarning"
        )
        #expect(
            AppTheme.solarPop.themedAssetName(defaultAsset: "AccentColor", variantSuffix: "Accent")
                == "SolarAccent"
        )
        #expect(
            AppTheme.shanksRed.themedAssetName(defaultAsset: "ScoreExcellent", variantSuffix: "ScoreExcellent")
                == "ShanksScoreExcellent"
        )
        #expect(
            AppTheme.hanok.themedAssetName(defaultAsset: "MetricSleep", variantSuffix: "MetricSleep")
                == "HanokMetricSleep"
        )
    }
}
