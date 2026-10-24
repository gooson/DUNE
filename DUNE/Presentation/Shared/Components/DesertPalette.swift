import SwiftUI

/// Opaque, appearance-aware surfaces keep the dune scene behind readable data.
enum DesertPalette {
    static let surface = Color("DesertHorizonSurface")
    static let horizonTop = Color("DesertHorizonTop")
    static let horizonMiddle = Color("DesertHorizonMiddle")
    static let card = Color("DesertHorizonCard")
    static let support = Color("DesertHorizonSupport")
    static let border = Color("DesertHorizonBorder")
    static let ink = Color("DesertHorizonInk")
    static let muted = Color("DesertHorizonMuted")
    static let duneFar = Color("DesertHorizonDuneFar")
    static let duneMid = Color("DesertHorizonDuneMid")
    static let duneNear = Color("DesertHorizonDuneNear")
}

struct DesertCardSurface: View {
    let cornerRadius: CGFloat
    var isSupporting = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isSupporting ? DesertPalette.support : DesertPalette.card)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesertPalette.border, lineWidth: 1)
            }
    }
}

#Preview {
    DesertCardSurface(cornerRadius: 20)
        .frame(width: 320, height: 160)
        .padding()
        .background(DesertPalette.surface)
}
