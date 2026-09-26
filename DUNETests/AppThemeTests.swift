import Foundation
import Testing
import UIKit
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
        #expect(AppTheme.contourAtlas.rawValue == "contourAtlas")
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
        #expect(AppTheme.allCases.count == 7)
        #expect(AppTheme.allCases.contains(.desertWarm))
        #expect(AppTheme.allCases.contains(.oceanCool))
        #expect(AppTheme.allCases.contains(.forestGreen))
        #expect(AppTheme.allCases.contains(.sakuraCalm))
        #expect(AppTheme.allCases.contains(.arcticDawn))
        #expect(AppTheme.allCases.contains(.solarPop))
        #expect(AppTheme.allCases.contains(.contourAtlas))
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
        #expect(AppTheme.contourAtlas.assetPrefix == "Contour")
    }

    @Test("usesGlassBorder returns true for glass-border themes")
    func glassBorderThemes() {
        let glassThemes: [AppTheme] = [.sakuraCalm, .arcticDawn, .solarPop]
        let plainThemes: [AppTheme] = [.desertWarm, .oceanCool, .forestGreen, .contourAtlas]

        for theme in glassThemes {
            #expect(theme.usesGlassBorder == true)
        }
        for theme in plainThemes {
            #expect(theme.usesGlassBorder == false)
        }
    }

    @Test("Contour selection survives persisted-value normalization")
    func contourPersistence() {
        #expect(AppTheme.resolvedTheme(fromPersistedRawValue: " contourAtlas ") == .contourAtlas)
        #expect(AppTheme.normalizedRawValue(fromPersistedRawValue: "contourAtlas") == "contourAtlas")
    }

    @Test("Contour resolves every required color asset in both appearances")
    @MainActor
    func contourAssets() throws {
        let suffixes = [
            "Accent", "Bronze", "Dusk", "Sand", "Background", "Ink", "CardBackground",
            "TabTrain", "TabWellness", "TabLife",
            "ScoreExcellent", "ScoreGood", "ScoreFair", "ScoreTired", "ScoreWarning",
            "MetricHRV", "MetricRHR", "MetricHeartRate", "MetricSleep", "MetricActivity", "MetricSteps", "MetricBody",
            "WeatherRain", "WeatherSnow", "WeatherCloudy", "WeatherNight"
        ]
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for suffix in suffixes {
                let name = AppTheme.contourAtlas.themedAssetName(defaultAsset: "unused", variantSuffix: suffix)
                let color = try #require(UIColor(named: name), "Missing asset: \(name)")
                #expect(color.resolvedColor(with: traits).cgColor.alpha == 1)
            }
            for foreground in ["ContourAccent", "ContourBronze", "ContourSand"] {
                let text = try #require(UIColor(named: foreground)).resolvedColor(with: traits)
                for background in ["ContourBackground", "ContourCardBackground"] {
                    let surface = try #require(UIColor(named: background)).resolvedColor(with: traits)
                    let values = [luminance(text), luminance(surface)].sorted()
                    #expect((values[1] + 0.05) / (values[0] + 0.05) >= 4.5,
                            "\(foreground) must remain readable on \(background)")
                }
            }
        }
    }

    private func luminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let linear = [r, g, b].map { value in
            let value = Double(value)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }
}
