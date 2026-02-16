import SwiftUI

struct SmartCardGrid: View {
    let metrics: [HealthMetric]

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var gridSpacing: CGFloat { sizeClass == .regular ? DS.Spacing.lg : DS.Spacing.md }

    private var columns: [GridItem] {
        let count = sizeClass == .regular ? 3 : 2
        return Array(
            repeating: GridItem(.flexible(), spacing: gridSpacing),
            count: count
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                NavigationLink(value: metric) {
                    MetricCardView(metric: metric)
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .contextMenu {
                    NavigationLink(value: metric) {
                        Label("View Trend", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    NavigationLink(value: AllDataDestination(category: metric.category)) {
                        Label("Show All Data", systemImage: "list.bullet")
                    }
                } preview: {
                    MetricCardView(metric: metric)
                        .padding()
                        .frame(width: 240)
                }
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .opacity
                                .combined(with: .offset(y: 8))
                                .animation(DS.Animation.standard),
                            removal: .opacity
                        )
                )
            }
        }
        .animation(DS.Animation.standard, value: metrics.map(\.id))
    }
}
