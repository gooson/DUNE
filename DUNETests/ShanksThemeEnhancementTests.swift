import SwiftUI
import Testing
@testable import DUNE

@Suite("Shanks Theme Enhancement")
struct ShanksThemeEnhancementTests {
    @Test("Pirate sigil path is generated for square rect")
    func pirateSigilPathSquare() {
        let sigil = ShanksPirateFlagSigil()
        let path = sigil.path(in: CGRect(x: 0, y: 0, width: 140, height: 140))

        #expect(path.isEmpty == false)
    }

    @Test("Pirate sigil path is generated for wide rect")
    func pirateSigilPathWide() {
        let sigil = ShanksPirateFlagSigil()
        let path = sigil.path(in: CGRect(x: 0, y: 0, width: 220, height: 120))

        #expect(path.isEmpty == false)
    }

    @Test("Pirate sigil path is empty for zero-size rect")
    func pirateSigilPathZeroSize() {
        let sigil = ShanksPirateFlagSigil()
        let path = sigil.path(in: .zero)

        #expect(path.isEmpty == true)
    }

    @Test("Foam crest path is generated for wide rect")
    func foamCrestPathWide() {
        let shape = ShanksFoamCrestShape(
            amplitude: 0.06,
            frequency: 1.5,
            phase: .pi / 4,
            verticalOffset: 0.2,
            bandDepth: 0.1
        )
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 280, height: 120))

        #expect(path.isEmpty == false)
    }

    @Test("Foam crest path is empty for zero-size rect")
    func foamCrestPathZeroSize() {
        let shape = ShanksFoamCrestShape()
        let path = shape.path(in: .zero)

        #expect(path.isEmpty == true)
    }

    @Test("Ship silhouette path is generated for wide rect")
    func shipSilhouettePathWide() {
        let ship = ShanksRedForceSilhouetteShape()
        let path = ship.path(in: CGRect(x: 0, y: 0, width: 220, height: 120))

        #expect(path.isEmpty == false)
    }

    @Test("Ship silhouette path is empty for zero-size rect")
    func shipSilhouettePathZeroSize() {
        let ship = ShanksRedForceSilhouetteShape()
        let path = ship.path(in: .zero)

        #expect(path.isEmpty == true)
    }

    @Test("Scene presets keep the ocean start line below the top edge")
    func scenePresetTopInsetsArePositive() {
        let presets: [ShanksSceneStyle] = [
            .tab(for: .today),
            .tab(for: .train),
            .tab(for: .wellness),
            .tab(for: .life),
            .detail,
            .sheet,
        ]

        for style in presets {
            #expect(style.sceneTopInset > 0)
            #expect(style.sceneHeight > 0)
            #expect(style.sceneTopInset < style.sceneHeight)
        }
    }

    @Test("Scene presets tier ocean start line by presentation depth")
    func scenePresetTopInsetTiering() {
        let tab = ShanksSceneStyle.tab(for: .today)
        let detail = ShanksSceneStyle.detail
        let sheet = ShanksSceneStyle.sheet
        let life = ShanksSceneStyle.tab(for: .life)

        #expect(tab.sceneTopInset > detail.sceneTopInset)
        #expect(detail.sceneTopInset > sheet.sceneTopInset)
        #expect(tab.sceneTopInset > life.sceneTopInset)
    }

    @Test("Hero frame start line uses lower-quarter anchor")
    func heroFrameStartLineInset() {
        let frame = CGRect(x: 0, y: 24, width: 320, height: 200)
        let inset = TabHeroStartLine.inset(for: frame)

        #expect(inset == 174.0)
    }

    @Test("Hero frame start line clamps zero-height frames")
    func heroFrameStartLineInsetZeroHeight() {
        let inset = TabHeroStartLine.inset(for: CGRect(x: 0, y: 32, width: 320, height: 0))

        #expect(inset == 0.0)
    }
}
