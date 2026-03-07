import CoreGraphics
import Foundation
import Testing
@testable import DUNE

@Suite("ChartSelectionInteraction")
struct ChartSelectionInteractionTests {
    @Test("Selection activates after hold duration within movement slop")
    func activatesAfterHoldDuration() {
        var state = ChartSelectionGestureState()
        let start = Date(timeIntervalSinceReferenceDate: 100)

        let initial = state.registerChange(at: start, translation: .zero)
        let activated = state.registerChange(
            at: start.addingTimeInterval(ChartSelectionInteraction.holdDuration + 0.02),
            translation: CGSize(width: 4, height: 3)
        )

        #expect(initial == false)
        #expect(activated == true)
        #expect(state.isActive == true)
        #expect(state.isCancelled == false)
    }

    @Test("Selection is cancelled when movement exceeds slop before activation")
    func cancelsWhenMovementExceedsSlop() {
        var state = ChartSelectionGestureState()
        let start = Date(timeIntervalSinceReferenceDate: 200)

        _ = state.registerChange(at: start, translation: .zero)
        let activated = state.registerChange(
            at: start.addingTimeInterval(0.05),
            translation: CGSize(width: ChartSelectionInteraction.activationDistance + 2, height: 0)
        )

        #expect(activated == false)
        #expect(state.isActive == false)
        #expect(state.isCancelled == true)
    }

    @Test("Nearest point snaps to closest date")
    func nearestPointSnap() {
        let points = [
            ChartDataPoint(date: Date(timeIntervalSinceReferenceDate: 0), value: 1),
            ChartDataPoint(date: Date(timeIntervalSinceReferenceDate: 10), value: 2),
            ChartDataPoint(date: Date(timeIntervalSinceReferenceDate: 20), value: 3),
        ]

        let selected = ChartSelectionInteraction.nearestPoint(
            to: Date(timeIntervalSinceReferenceDate: 12),
            in: points,
            date: \.date
        )

        #expect(selected?.date == Date(timeIntervalSinceReferenceDate: 10))
    }

    @Test("Overlay clamps to leading edge inside chart bounds")
    func overlayLeadingClamp() {
        let layout = ChartSelectionInteraction.overlayLayout(
            anchor: CGPoint(x: 20, y: 90),
            overlaySize: CGSize(width: 100, height: 34),
            chartSize: CGSize(width: 320, height: 220),
            plotFrame: CGRect(x: 40, y: 20, width: 240, height: 150)
        )

        #expect(layout.center.x == 62)
        #expect(layout.edge == .above)
    }

    @Test("Overlay flips below when there is no room above the anchor")
    func overlayFlipsBelow() {
        let layout = ChartSelectionInteraction.overlayLayout(
            anchor: CGPoint(x: 160, y: 28),
            overlaySize: CGSize(width: 100, height: 34),
            chartSize: CGSize(width: 320, height: 220),
            plotFrame: CGRect(x: 40, y: 20, width: 240, height: 150)
        )

        #expect(layout.edge == .below)
        #expect(layout.center.y > 28)
    }

    @Test("Overlay stays above and clamps vertically when bottom space is limited")
    func overlayAboveClampNearBottom() {
        let layout = ChartSelectionInteraction.overlayLayout(
            anchor: CGPoint(x: 160, y: 150),
            overlaySize: CGSize(width: 100, height: 34),
            chartSize: CGSize(width: 320, height: 220),
            plotFrame: CGRect(x: 40, y: 20, width: 240, height: 160)
        )

        #expect(layout.edge == .above)
        #expect(layout.center.y < 150)
        #expect(layout.center.y >= 25)
    }
}
