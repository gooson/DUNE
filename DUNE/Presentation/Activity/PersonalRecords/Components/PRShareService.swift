import SwiftUI

/// Service for rendering a PRShareCard into a shareable UIImage.
/// Follows the same explicit-size pattern as WorkoutShareService (correction #209).
@MainActor
enum PRShareService {
    static let renderWidth: CGFloat = 360

    /// Render a PR share card to UIImage. Returns nil if rendering fails.
    static func renderShareImage(data: PRShareData, accentColor: Color) -> UIImage? {
        let renderSize = measuredRenderSize(data: data, accentColor: accentColor)
        guard renderSize.width > 0, renderSize.height > 0 else {
            AppLogger.ui.error("PR share image skipped because measured size was invalid: \(renderSize.debugDescription)")
            return nil
        }

        let card = renderableCard(data: data, accentColor: accentColor)
            .frame(width: renderSize.width, height: renderSize.height, alignment: .topLeading)
        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = .init(width: renderSize.width, height: renderSize.height)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    static func measuredRenderSize(data: PRShareData, accentColor: Color) -> CGSize {
        let hostingController = UIHostingController(
            rootView: renderableCard(data: data, accentColor: accentColor)
        )
        let measured = hostingController.sizeThatFits(
            in: CGSize(width: renderWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        return CGSize(
            width: ceil(max(0, measured.width)),
            height: ceil(max(0, measured.height))
        )
    }

    /// Build PRShareData from an ActivityPersonalRecord.
    static func buildShareData(from record: ActivityPersonalRecord) -> PRShareData {
        PRShareData(
            exerciseName: record.localizedTitle,
            kindDisplayName: record.kind.displayName,
            kindIconName: record.kind.iconName,
            formattedValue: record.formattedValue,
            unitLabel: record.kind.unitLabel,
            formattedDelta: record.formattedDelta,
            date: record.date
        )
    }

    private static func renderableCard(data: PRShareData, accentColor: Color) -> some View {
        PRShareCard(data: data, accentColor: accentColor)
            .frame(width: renderWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
