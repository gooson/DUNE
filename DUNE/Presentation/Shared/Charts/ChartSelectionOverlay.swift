import SwiftUI

/// Shared selection overlay shown on chart interaction.
/// Displays date and value in a themed capsule at the top of the chart.
struct ChartSelectionOverlay: View {
    let date: Date
    let value: String
    var dateFormat: Date.FormatStyle = .dateTime.month(.abbreviated).day()

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack {
            Text(date, format: dateFormat)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundStyle(theme.sandColor)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .chartSurface(cornerRadius: DS.Radius.sm, topBloomHeight: 18)
        .padding(.horizontal, DS.Spacing.xs)
        .accessibilityIdentifier("chart-selection-overlay")
    }
}

struct FloatingChartSelectionOverlay: View {
    let date: Date
    let value: String
    let anchor: CGPoint
    let chartSize: CGSize
    let plotFrame: CGRect
    var dateFormat: Date.FormatStyle = .dateTime.month(.abbreviated).day()

    @State private var overlaySize = ChartSelectionInteraction.defaultOverlaySize

    private var layout: ChartSelectionOverlayLayout {
        ChartSelectionInteraction.overlayLayout(
            anchor: anchor,
            overlaySize: overlaySize,
            chartSize: chartSize,
            plotFrame: plotFrame
        )
    }

    var body: some View {
        ChartSelectionOverlay(
            date: date,
            value: value,
            dateFormat: dateFormat
        )
        .fixedSize()
        .onGeometryChange(for: CGSize.self) { geometry in
            geometry.size
        } action: { newSize in
            overlaySize = newSize
        }
        .position(layout.center)
        .allowsHitTesting(false)
    }
}

extension View {
    func chartSurface(cornerRadius: CGFloat, topBloomHeight: CGFloat? = nil) -> some View {
        modifier(ChartSurfaceModifier(cornerRadius: cornerRadius, topBloomHeight: topBloomHeight))
    }
}

private struct ChartSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let topBloomHeight: CGFloat?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var borderOpacity: Double {
        colorScheme == .dark ? 0.26 : 0.16
    }

    private var fillOpacity: Double {
        colorScheme == .dark ? 0.34 : 0.22
    }

    private var bloomOpacity: Double {
        colorScheme == .dark ? 0.18 : 0.12
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(theme.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(theme.cardBackgroundGradient)
                            .opacity(fillOpacity)
                    }
                    .overlay(alignment: .top) {
                        if let topBloomHeight {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            theme.accentColor.opacity(bloomOpacity),
                                            .clear,
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: topBloomHeight)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(theme.accentColor.opacity(borderOpacity), lineWidth: 1)
                    }
            }
    }
}
