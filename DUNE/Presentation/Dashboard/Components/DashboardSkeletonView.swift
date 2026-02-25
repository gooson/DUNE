import SwiftUI

/// Placeholder skeleton shown during dashboard loading.
/// Matches the layout shape of the actual dashboard content.
struct DashboardSkeletonView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columnCount: Int { sizeClass == .regular ? 3 : 2 }
    private var cardHeight: CGFloat { sizeClass == .regular ? 100 : 80 }

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Hero card placeholder
            RoundedRectangle(cornerRadius: DS.Radius.xxl)
                .fill(.thinMaterial)
                .frame(height: 120)

            // Metric cards placeholder
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.md), count: columnCount),
                spacing: DS.Spacing.md
            ) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(.thinMaterial)
                        .frame(height: cardHeight)
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}
