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
}
