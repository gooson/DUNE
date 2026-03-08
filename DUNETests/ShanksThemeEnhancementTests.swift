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
}
