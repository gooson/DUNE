import AVFoundation
import SwiftUI
import Testing
@testable import DUNE

@MainActor
@Suite("Artist theme editions")
struct ArtistThemeEditionTests {
    @Test func motionRequiresAVisibleActiveSurface() {
        #expect(ArtistThemeBackground.playsMotion(visible: true, phase: .active, reduced: false, lowPower: false))
        #expect(!ArtistThemeBackground.playsMotion(visible: false, phase: .active, reduced: false, lowPower: false))
        #expect(!ArtistThemeBackground.playsMotion(visible: true, phase: .inactive, reduced: false, lowPower: false))
        #expect(!ArtistThemeBackground.playsMotion(visible: true, phase: .background, reduced: false, lowPower: false))
        #expect(!ArtistThemeBackground.playsMotion(visible: true, phase: .active, reduced: true, lowPower: false))
        #expect(!ArtistThemeBackground.playsMotion(visible: true, phase: .active, reduced: false, lowPower: true))
    }

    @Test("Positive score changes and primary actions remain readable on their opaque fills")
    func opaqueSurfaceContrast() {
        for scheme in [ColorScheme.light, .dark] {
            var environment = EnvironmentValues()
            environment.colorScheme = scheme

            for theme in AppTheme.allCases {
                let buttonInk = theme.prominentButtonForegroundColor(for: scheme).resolve(in: environment)
                let buttonFill = theme.accentColor.resolve(in: environment)
                #expect(contrast(buttonInk, on: buttonFill) >= 4.5,
                        "\(theme.rawValue) \(scheme): primary action label")

                if ArtistThemeEdition.forTheme(theme) != nil {
                    let palette = ScoreHeroPalette(theme: theme, colorScheme: scheme)
                    let positive = palette.heroPositive.resolve(in: environment)
                    let hero = palette.surface.resolve(in: environment)
                    #expect(contrast(positive, on: hero) >= 4.5,
                            "\(theme.rawValue) \(scheme): positive score change")
                }
            }
        }
    }

    @Test func eachInstalledEditionHasAReadableStillAndSilentLoop() async throws {
        let folder = try #require(Bundle.main.url(forResource: "ArtistEditions", withExtension: nil))
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let keys = Set(files.filter { ["json", "jpg", "mp4"].contains($0.pathExtension) }
            .map { $0.deletingPathExtension().lastPathComponent })
        for name in keys.sorted() {
            let theme = try #require(AppTheme(rawValue: name))
            let edition = try #require(ArtistThemeEdition.forTheme(theme), "Incomplete edition: \(name)")
            let poster = try #require(edition.poster)
            #expect(poster.size.width > poster.size.height)
            let movie = AVURLAsset(url: edition.movieURL)
            let videos = try await movie.loadTracks(withMediaType: .video)
            let audio = try await movie.loadTracks(withMediaType: .audio)
            let duration = try await movie.load(.duration)
            #expect(videos.count == 1)
            #expect(audio.isEmpty)
            #expect(duration.seconds >= 3)
        }
    }

    private func contrast(_ foreground: Color.Resolved, on background: Color.Resolved) -> Float {
        func luminance(_ color: Color.Resolved) -> Float {
            0.2126 * color.linearRed + 0.7152 * color.linearGreen + 0.0722 * color.linearBlue
        }

        let ink = luminance(foreground)
        let fill = luminance(background)
        return (max(ink, fill) + 0.05) / (min(ink, fill) + 0.05)
    }
}
