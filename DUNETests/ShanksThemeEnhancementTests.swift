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
}
