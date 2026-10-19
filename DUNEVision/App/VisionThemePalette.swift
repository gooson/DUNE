import SwiftUI

/// The visionOS target shares theme choices and color assets with the main app.
enum VisionThemePalette {
    static func displayName(for theme: AppTheme) -> String {
        switch theme {
        case .desertWarm: String(localized: "Desert Warm")
        case .oceanCool: String(localized: "Ocean Cool")
        case .forestGreen: String(localized: "Forest Green")
        case .sakuraCalm: String(localized: "Sakura Calm")
        case .arcticDawn: String(localized: "Arctic Dawn")
        case .solarPop: String(localized: "Solar Pop")
        case .contourAtlas: String(localized: "Contour Atlas")
        case .waterLilies: String(localized: "Water Lilies")
        }
    }

    static func accentColor(for theme: AppTheme) -> Color {
        let assetName: String
        switch theme {
        case .desertWarm: assetName = "AccentColor"
        case .oceanCool: assetName = "OceanAccent"
        case .forestGreen: assetName = "ForestAccent"
        case .sakuraCalm: assetName = "SakuraAccent"
        case .arcticDawn: assetName = "ArcticAccent"
        case .solarPop: assetName = "SolarAccent"
        case .contourAtlas: assetName = "ContourAccent"
        case .waterLilies: assetName = "LilyAccent"
        }
        return Color(assetName)
    }
}
