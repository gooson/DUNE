import SwiftUI

/// Shared existing Today colors for its root and detail heroes.
@MainActor
struct ScoreHeroPalette {
    let theme: AppTheme
    let colorScheme: ColorScheme

    private var edition: ArtistThemeEdition? { ArtistThemeEdition.forTheme(theme) }

    var isDesert: Bool { theme == .desertWarm }
    /// Every direction preview uses an opaque dark Today hero in both appearances.
    var surface: Color {
        if let edition { return edition.hero }
        return switch theme {
        case .desertWarm: Color(red: 0.208, green: 0.180, blue: 0.161)
        case .oceanCool: Color(red: 0.063, green: 0.165, blue: 0.231)
        case .forestGreen: Color(red: 0.114, green: 0.208, blue: 0.153)
        case .sakuraCalm: Color(red: 0.282, green: 0.176, blue: 0.243)
        case .arcticDawn: Color(red: 0.082, green: 0.161, blue: 0.263)
        case .solarPop: Color(red: 0.243, green: 0.157, blue: 0.153)
        case .contourAtlas: Color(red: 0.157, green: 0.188, blue: 0.161)
        case .waterLilies: Color(red: 0.188, green: 0.212, blue: 0.286)
        }
    }
    var track: Color {
        if let edition { return edition.highlight }
        return isDesert ? Color(red: 0.435, green: 0.353, blue: 0.227) : heroAccent
    }

    var border: Color {
        if let edition { return edition.highlight.opacity(0.36) }
        return switch theme {
        case .desertWarm: Color(red: 0.455, green: 0.365, blue: 0.263)
        case .oceanCool: Color(red: 0.227, green: 0.400, blue: 0.478)
        case .forestGreen: Color(red: 0.298, green: 0.416, blue: 0.298)
        case .sakuraCalm: Color(red: 0.588, green: 0.420, blue: 0.510)
        case .arcticDawn: Color(red: 0.318, green: 0.439, blue: 0.557)
        case .solarPop: Color(red: 0.596, green: 0.376, blue: 0.282)
        case .contourAtlas: Color(red: 0.380, green: 0.455, blue: 0.318)
        case .waterLilies: Color(red: 0.408, green: 0.463, blue: 0.549)
        }
    }
    var gold: Color { edition?.highlight ?? (isDesert ? Color(red: 0.886, green: 0.718, blue: 0.380) : theme.accentColor) }
    var paleGold: Color { isDesert ? Color(red: 0.969, green: 0.843, blue: 0.471) : theme.duskColor }
    /// The card stays dark in light appearance, while these three themes use
    /// dark accents on the surrounding light canvas.
    var heroAccent: Color {
        if let edition { return edition.highlight }
        guard colorScheme == .light else { return gold }
        return switch theme {
        case .sakuraCalm: Color(red: 0.992, green: 0.545, blue: 0.735)
        case .contourAtlas: Color(red: 0.808, green: 0.910, blue: 0.514)
        case .waterLilies: Color(red: 0.906, green: 0.667, blue: 0.792)
        default: gold
        }
    }
    var heroHighlight: Color {
        if let edition { return edition.heroInk }
        if colorScheme == .light && (theme == .sakuraCalm || theme == .contourAtlas || theme == .waterLilies) {
            return ink
        }
        return paleGold
    }
    /// Data must stay readable on the opaque dark hero in either appearance.
    /// The dusk highlight belongs to the ring, where it is only a gradient stop.
    var trendLine: Color { edition?.highlight ?? (isDesert ? heroHighlight : heroAccent) }
    var heroPositive: Color {
        if edition != nil {
            var environment = EnvironmentValues()
            environment.colorScheme = .dark
            let color = theme.scoreGood.resolve(in: environment)
            return Color(.sRGBLinear, red: Double(color.linearRed), green: Double(color.linearGreen), blue: Double(color.linearBlue))
        }
        if colorScheme == .light && theme == .contourAtlas {
            return Color(red: 0.741, green: 0.835, blue: 0.525)
        }
        if colorScheme == .light && theme == .waterLilies {
            return Color(red: 0.502, green: 0.722, blue: 0.478)
        }
        return theme.scoreGood
    }
    var muted: Color {
        if let edition { return edition.heroInk.opacity(0.80) }
        return isDesert ? Color(red: 0.831, green: 0.784, blue: 0.722) : ink.opacity(0.76)
    }

    var ink: Color {
        if let edition { return edition.heroInk }
        return switch theme {
        case .desertWarm: Color(red: 1, green: 0.961, blue: 0.910)
        case .oceanCool: Color(red: 0.941, green: 0.984, blue: 1)
        case .forestGreen: Color(red: 0.969, green: 0.965, blue: 0.910)
        case .sakuraCalm: Color(red: 1, green: 0.969, blue: 0.980)
        case .arcticDawn: Color(red: 0.969, green: 0.988, blue: 1)
        case .solarPop: Color(red: 1, green: 0.973, blue: 0.929)
        case .contourAtlas: Color(red: 0.953, green: 0.973, blue: 0.914)
        case .waterLilies: Color(red: 1, green: 0.965, blue: 0.984)
        }
    }

}
