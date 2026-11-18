import SwiftUI

extension View {
    func forestHeroArtwork(
        _ preset: WavePreset,
        cornerRadius: CGFloat,
        borderColor: Color,
        prefersFooter: Bool = false
    ) -> some View {
        modifier(ForestHeroArtworkModifier(
            preset: preset,
            cornerRadius: cornerRadius,
            borderColor: borderColor,
            prefersFooter: prefersFooter
        ))
    }
}

private struct ForestHeroArtworkModifier: ViewModifier {
    let preset: WavePreset
    let cornerRadius: CGFloat
    let borderColor: Color
    let prefersFooter: Bool

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if theme == .forestGreen, ArtistThemeEdition.forTheme(theme) == nil {
            let outline = RoundedRectangle(cornerRadius: cornerRadius)
            ForestHeroArtworkLayout(prefersStack: prefersFooter || dynamicTypeSize >= .xxLarge) {
                content
                ForestCanopyArtwork(preset: preset)
            }
            .clipShape(outline)
            .overlay {
                outline.strokeBorder(borderColor, lineWidth: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        } else {
            content
        }
    }
}

/// Gives the illustration a separate region so it never draws behind card content.
private struct ForestHeroArtworkLayout: Layout {
    let prefersStack: Bool

    private let minimumPanelWidth: CGFloat = 330
    private let minimumContentWidth: CGFloat = 224
    private let minimumPanelHeight: CGFloat = 164
    private let stackedArtworkHeight: CGFloat = 72

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = if let proposedWidth = proposal.width, proposedWidth.isFinite {
            proposedWidth
        } else {
            subviews[0].sizeThatFits(.unspecified).width
        }
        let contentWidth = contentWidth(in: width)
        let contentHeight = subviews[0].sizeThatFits(.init(width: contentWidth, height: nil)).height
        let height = usesSidePanel(width: width)
            ? max(contentHeight, minimumPanelHeight)
            : contentHeight + stackedArtworkHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let contentWidth = contentWidth(in: bounds.width)
        let sidePanel = usesSidePanel(width: bounds.width)
        subviews[0].place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: .init(width: contentWidth, height: nil)
        )

        let artworkOrigin = sidePanel
            ? CGPoint(x: bounds.minX + contentWidth, y: bounds.minY)
            : CGPoint(x: bounds.minX, y: bounds.maxY - stackedArtworkHeight)
        let artworkSize = sidePanel
            ? ProposedViewSize(width: bounds.width - contentWidth, height: bounds.height)
            : ProposedViewSize(width: bounds.width, height: stackedArtworkHeight)
        subviews[1].place(at: artworkOrigin, anchor: .topLeading, proposal: artworkSize)
    }

    private func usesSidePanel(width: CGFloat) -> Bool {
        !prefersStack && width >= minimumPanelWidth
    }

    private func contentWidth(in width: CGFloat) -> CGFloat {
        usesSidePanel(width: width) ? max(width * 0.58, minimumContentWidth) : width
    }
}
