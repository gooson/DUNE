import SwiftUI
import UIKit

/// Each edition is installed as one palette, one illustrated still and one silent motion loop.
@MainActor
struct ArtistThemeEdition {
    let theme: AppTheme
    let posterURL: URL
    let movieURL: URL
    private let palette: Palette

    static func forTheme(_ theme: AppTheme) -> Self? { editions[theme] }

    private static let editions: [AppTheme: Self] = Dictionary(uniqueKeysWithValues: AppTheme.allCases.compactMap { theme in
        let folder = "ArtistEditions"
        let name = theme.rawValue
        guard let json = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: folder),
              let poster = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: folder),
              let movie = Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: folder),
              let data = try? Data(contentsOf: json),
              let palette = try? JSONDecoder().decode(Palette.self, from: data) else { return nil }
        return (theme, Self(theme: theme, posterURL: poster, movieURL: movie, palette: palette))
    })

    private struct Pigment: Decodable {
        let color: Color

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let hex = try container.decode(String.self)
            guard hex.count == 7, hex.first == "#", let rgb = UInt32(hex.dropFirst(), radix: 16) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected #RRGGBB")
            }
            color = Color(.sRGB, red: Double(rgb >> 16) / 255,
                          green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
        }
    }

    private struct Appearance: Decodable {
        let ground, surface, ink, accent, rim: Pigment
    }

    private struct Palette: Decodable {
        let light, dark: Appearance
        let hero, highlight: Pigment
        let raisedEdge: Bool?
    }

    private func appearance(_ scheme: ColorScheme) -> Appearance {
        scheme == .dark ? palette.dark : palette.light
    }

    var hero: Color { palette.hero.color }
    var highlight: Color { palette.highlight.color }
    var heroInk: Color { Color(red: 1.0, green: 0.977, blue: 0.945) }
    var hasRaisedEdge: Bool { palette.raisedEdge == true }
    func ground(for scheme: ColorScheme) -> Color { appearance(scheme).ground.color }
    func surface(for scheme: ColorScheme) -> Color { appearance(scheme).surface.color }
    func ink(for scheme: ColorScheme) -> Color { appearance(scheme).ink.color }
    func accent(for scheme: ColorScheme) -> Color { appearance(scheme).accent.color }
    func rim(for scheme: ColorScheme) -> Color { appearance(scheme).rim.color }

    private static let posters = NSCache<NSURL, UIImage>()
    var poster: UIImage? {
        let key = posterURL as NSURL
        if let cached = Self.posters.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: posterURL.path) else { return nil }
        Self.posters.setObject(image, forKey: key)
        return image
    }
}
