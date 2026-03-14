import Charts
import SwiftUI
import UIKit

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

struct ChartUITestSurface: UIViewRepresentable {
    let identifier: String
    let label: String
    let value: String

    func makeUIView(context: Context) -> ChartUITestSurfaceView {
        let view = ChartUITestSurfaceView()
        view.isUserInteractionEnabled = true
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        return view
    }

    func updateUIView(_ uiView: ChartUITestSurfaceView, context: Context) {
        uiView.accessibilityIdentifier = identifier
        uiView.accessibilityLabel = label
        uiView.accessibilityValue = value
    }
}

final class ChartUITestSurfaceView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        false
    }
}

extension View {
    func chartSurface(cornerRadius: CGFloat, topBloomHeight: CGFloat? = nil) -> some View {
        modifier(ChartSurfaceModifier(cornerRadius: cornerRadius, topBloomHeight: topBloomHeight))
    }

    func chartSelectionUITestProbe(
        _ label: String,
        identifier: String = "chart-selection-probe"
    ) -> some View {
        modifier(ChartSelectionUITestProbeModifier(label: label, identifier: identifier))
    }

    func scrollableChartSelectionOverlay<OverlayContent: View>(
        isScrollable: Bool = true,
        visibleDomainLength: TimeInterval?,
        scrollPosition: Binding<Date>?,
        selectedDate: Binding<Date?>,
        selectionState: Binding<ChartSelectionGestureState>,
        @ViewBuilder overlayContent: @escaping (ChartProxy, CGRect, CGSize) -> OverlayContent
    ) -> some View {
        modifier(
            ScrollableChartSelectionOverlayModifier(
                isScrollable: isScrollable,
                visibleDomainLength: visibleDomainLength,
                scrollPosition: scrollPosition,
                selectedDate: selectedDate,
                selectionState: selectionState,
                overlayContent: overlayContent
            )
        )
    }
}

struct ChartLongPressSelectionRecognizer: UIViewRepresentable {
    let minimumPressDuration: TimeInterval
    let onStateChange: @MainActor (UIGestureRecognizer.State, CGPoint) -> Void

    func makeUIView(context: Context) -> GestureAttachmentView {
        let view = GestureAttachmentView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.minimumPressDuration = minimumPressDuration
        view.onStateChange = onStateChange
        return view
    }

    func updateUIView(_ uiView: GestureAttachmentView, context: Context) {
        uiView.minimumPressDuration = minimumPressDuration
        uiView.onStateChange = onStateChange
        uiView.attachRecognizerIfNeeded()
    }
}

final class GestureAttachmentView: UIView, UIGestureRecognizerDelegate {
    var minimumPressDuration: TimeInterval = ChartSelectionInteraction.holdDuration {
        didSet {
            longPressRecognizer?.minimumPressDuration = minimumPressDuration
            longPressRecognizer?.allowableMovement = ChartSelectionInteraction.allowableMovement
        }
    }
    var onStateChange: (@MainActor (UIGestureRecognizer.State, CGPoint) -> Void)?

    private weak var recognitionView: UIView?
    private var longPressRecognizer: UILongPressGestureRecognizer?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        attachRecognizerIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachRecognizerIfNeeded()
    }

    func attachRecognizerIfNeeded() {
        guard let recognitionView = window ?? superview else { return }

        if self.recognitionView !== recognitionView {
            detachRecognizer()
        }

        guard longPressRecognizer == nil else { return }

        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.minimumPressDuration = minimumPressDuration
        recognizer.allowableMovement = ChartSelectionInteraction.allowableMovement
        recognizer.cancelsTouchesInView = true
        recognizer.delegate = self
        recognitionView.addGestureRecognizer(recognizer)

        self.recognitionView = recognitionView
        self.longPressRecognizer = recognizer
    }

    override func removeFromSuperview() {
        detachRecognizer()
        super.removeFromSuperview()
    }

    private func detachRecognizer() {
        if let longPressRecognizer, let recognitionView {
            recognitionView.removeGestureRecognizer(longPressRecognizer)
        }
        longPressRecognizer = nil
        recognitionView = nil
    }

    @objc
    private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        let state = recognizer.state
        let location = recognizer.location(in: self)
        Task { @MainActor in
            onStateChange?(state, location)
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if longPressRecognizer?.state == .began || longPressRecognizer?.state == .changed {
            if gestureRecognizer is UIPanGestureRecognizer || otherGestureRecognizer is UIPanGestureRecognizer {
                return false
            }
        }
        return true
    }
}

private struct ScrollableChartSelectionOverlayModifier<OverlayContent: View>: ViewModifier {
    let isScrollable: Bool
    let visibleDomainLength: TimeInterval?
    let scrollPosition: Binding<Date>?
    @Binding var selectedDate: Date?
    @Binding var selectionState: ChartSelectionGestureState
    let overlayContent: (ChartProxy, CGRect, CGSize) -> OverlayContent

    func body(content: Content) -> some View {
        configuredContent(content)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let plotFrame = proxy.plotFrame.map({ geometry[$0] }) {
                        ZStack(alignment: .topLeading) {
                            ChartLongPressSelectionRecognizer(
                                minimumPressDuration: ChartSelectionInteraction.holdDuration
                            ) { state, location in
                                ChartSelectionInteraction.handleLongPressSelection(
                                    state: state,
                                    location: location,
                                    proxy: proxy,
                                    plotFrame: plotFrame,
                                    selectionState: $selectionState,
                                    selectedDate: $selectedDate,
                                    scrollPosition: scrollPosition
                                )
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            overlayContent(proxy, plotFrame, geometry.size)
                        }
                        .animation(.easeInOut(duration: 0.15), value: selectedDate)
                    }
                }
            }
    }

    @ViewBuilder
    private func configuredContent(_ content: Content) -> some View {
        if isScrollable, let visibleDomainLength, let scrollPosition {
            content
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleDomainLength)
                .chartScrollPosition(x: scrollPosition)
                .onChange(of: scrollPosition.wrappedValue) { _, _ in
                    ChartSelectionInteraction.clearSelection(
                        selectionState: $selectionState,
                        selectedDate: $selectedDate
                    )
                }
        } else {
            content
        }
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

private struct ChartSelectionUITestProbeModifier: ViewModifier {
    let label: String
    let identifier: String

    private static let isEnabled = ProcessInfo.processInfo.arguments.contains("--uitesting")

    func body(content: Content) -> some View {
        content
            .overlay {
                if Self.isEnabled {
                    // Mirror the full chart bounds so the probe remains discoverable
                    // even when the chart is partially clipped during UI test scrolling.
                    ChartUITestSurface(
                        identifier: identifier,
                        label: label,
                        value: ""
                    )
                }
            }
    }
}
