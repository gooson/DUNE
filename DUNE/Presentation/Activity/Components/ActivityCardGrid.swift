import SwiftUI

/// Keeps heterogeneous iPad sections full width. Only cards within a section share a row.
struct ActivityTabletGrid: Layout {
    @MainActor static var isEnabled: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || ProcessInfo.processInfo.isiOSAppOnMac
    }

    static let contentMaxWidth: CGFloat = 1000
    let minimumCardWidth: CGFloat
    let maximumColumns: Int
    private let spacing = DS.Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let idealWidth = CGFloat(maximumColumns) * minimumCardWidth + CGFloat(maximumColumns - 1) * spacing
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth
        return CGSize(width: width, height: arrange(subviews, width: width))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        arrange(subviews, width: bounds.width, origin: bounds.origin)
    }

    @discardableResult
    private func arrange(_ subviews: Subviews, width: CGFloat, origin: CGPoint? = nil) -> CGFloat {
        guard !subviews.isEmpty else { return 0 }
        let columns = (1...maximumColumns).last { count in
            CGFloat(count) * minimumCardWidth + CGFloat(count - 1) * spacing <= width
        } ?? 1
        var y: CGFloat = 0
        for start in stride(from: 0, to: subviews.count, by: columns) {
            let row = subviews[start..<min(start + columns, subviews.count)]
            let cellWidth = max(0, width - CGFloat(row.count - 1) * spacing) / CGFloat(row.count)
            let naturalSize = ProposedViewSize(width: cellWidth, height: nil)
            let rowHeight = row.map { $0.sizeThatFits(naturalSize).height }.max() ?? 0
            if let origin {
                for (column, cell) in row.enumerated() {
                    let point = CGPoint(x: origin.x + CGFloat(column) * (cellWidth + spacing), y: origin.y + y)
                    cell.place(at: point, anchor: .topLeading, proposal: .init(width: cellWidth, height: rowHeight))
                }
            }
            y += rowHeight + spacing
        }
        return y - spacing
    }
}

struct ActivityCardGrid<Content: View>: View {
    let minimumCardWidth: CGFloat
    let maximumColumns: Int
    @ViewBuilder var content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: DS.Spacing.sm, content: content)
        } else if ActivityTabletGrid.isEnabled {
            ActivityTabletGrid(minimumCardWidth: minimumCardWidth * typeScale, maximumColumns: maximumColumns) {
                content()
            }
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm), count: 2),
                      spacing: DS.Spacing.sm, content: content)
        }
    }
}
