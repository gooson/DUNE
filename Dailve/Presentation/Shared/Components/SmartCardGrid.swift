import SwiftUI

struct SmartCardGrid: View {
    let metrics: [HealthMetric]

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        let count = sizeClass == .regular ? 3 : 2
        return Array(
            repeating: GridItem(.flexible(), spacing: DS.Spacing.md),
            count: count
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                MetricCardView(metric: metric)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .offset(y: 8))
                                .animation(DS.Animation.standard.delay(Double(index) * 0.05)),
                            removal: .opacity
                        )
                    )
            }
        }
        .animation(DS.Animation.standard, value: metrics.map(\.id))
    }
}
