import SwiftUI

extension AppIconStyle {
    var displayName: String {
        switch self {
        case .interleave: String(localized: "Interleave")
        case .ocean: String(localized: "Ocean Glass")
        case .flow: String(localized: "Negative Flow")
        }
    }

    func previewAssetName(for theme: AppTheme) -> String {
        "AppIconPreview-\(rawValue)-\(theme.rawValue)"
    }

    func launchBrandAssetName(for theme: AppTheme) -> String {
        "LaunchBrand-\(rawValue)-\(theme.rawValue)"
    }

    func alternateIconName(for theme: AppTheme) -> String? {
        if self == .defaultStyle && theme == .desertWarm { return nil }
        return "AppIcon-\(rawValue)-\(theme.rawValue)"
    }
}

extension AppTheme {
    var appIconPaletteName: String {
        switch self {
        case .desertWarm: String(localized: "Coral × Sand")
        case .oceanCool: String(localized: "Mint × Periwinkle")
        case .forestGreen: String(localized: "Sage × Cream")
        case .sakuraCalm: String(localized: "Rose × Plum")
        case .arcticDawn: String(localized: "Ice × Denim")
        case .solarPop: String(localized: "Ultramarine × Coral")
        case .contourAtlas: String(localized: "Moss × Jade")
        case .waterLilies: String(localized: "Violet × Mint")
        }
    }

    var appIconBackgroundColor: Color {
        switch self {
        case .desertWarm: IconBackground.desert
        case .oceanCool: IconBackground.ocean
        case .forestGreen: IconBackground.forest
        case .sakuraCalm: IconBackground.sakura
        case .arcticDawn: IconBackground.arctic
        case .solarPop: IconBackground.solar
        case .contourAtlas: IconBackground.contour
        case .waterLilies: IconBackground.lily
        }
    }
}

private enum IconBackground {
    static let desert = Color(red: 0x34 / 255.0, green: 0x2A / 255.0, blue: 0x2B / 255.0)
    static let ocean = Color(red: 0x14 / 255.0, green: 0x2A / 255.0, blue: 0x35 / 255.0)
    static let forest = Color(red: 0x1C / 255.0, green: 0x30 / 255.0, blue: 0x2B / 255.0)
    static let sakura = Color(red: 0x2D / 255.0, green: 0x23 / 255.0, blue: 0x33 / 255.0)
    static let arctic = Color(red: 0x1C / 255.0, green: 0x28 / 255.0, blue: 0x3E / 255.0)
    static let solar = Color(red: 0x20 / 255.0, green: 0x22 / 255.0, blue: 0x39 / 255.0)
    static let contour = Color(red: 0x20 / 255.0, green: 0x2E / 255.0, blue: 0x29 / 255.0)
    static let lily = Color(red: 0x24 / 255.0, green: 0x28 / 255.0, blue: 0x3A / 255.0)
}
