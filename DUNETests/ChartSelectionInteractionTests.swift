import CoreGraphics
import Foundation
import Testing
@testable import DUNE

@Suite("ChartSelectionInteraction")
struct ChartSelectionInteractionTests {
    @Test("Selection enters pending phase before activation and keeps scroll enabled")
    func pendingPhaseKeepsScrollEnabled() {
        var state = ChartSelectionGestureState()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let initialScroll = Date(timeIntervalSinceReferenceDate: 80)

        let initial = state.registerChange(
            at: start,
            translation: .zero,
            currentScrollPosition: initialScroll
        )

        #expect(initial == .inactive)
        #expect(state.phase == .pendingActivation)
        #expect(state.startTime == start)
        #expect(state.initialScrollPosition == initialScroll)
        #expect(state.allowsScroll == true)
        #expect(state.isCancelled == false)
    }

    @Test("Selection activates after hold duration and restores initial scroll position")
    func activatesAfterHoldDuration() {
        var state = ChartSelectionGestureState()
        let start = Date(timeIntervalSinceReferenceDate: 200)
        let initialScroll = Date(timeIntervalSinceReferenceDate: 180)

        _ = state.registerChange(
            at: start,
            translation: .zero,
            currentScrollPosition: initialScroll
        )
        let activated = state.registerChange(
            at: start.addingTimeInterval(ChartSelectionInteraction.holdDuration + 0.02),
            translation: CGSize(width: 4, height: 3),
            currentScrollPosition: Date(timeIntervalSinceReferenceDate: 195)
        )

        #expect(activated == .activated(restoreScrollPosition: initialScroll))
        #expect(state.phase == .selecting)
        #expect(state.isSelecting == true)
        #expect(state.allowsScroll == false)
        #expect(state.isCancelled == false)
    }

    @Test("Selection is cancelled when movement exceeds slop before activation")
    func cancelsWhenMovementExceedsSlop() {
        var state = ChartSelectionGestureState()
        let start = Date(timeIntervalSinceReferenceDate: 240)

        _ = state.registerChange(at: start, translation: .zero)
        let activated = state.registerChange(
            at: start.addingTimeInterval(0.05),
            translation: CGSize(width: ChartSelectionInteraction.activationDistance + 2, height: 0)
        )

        #expect(activated == .inactive)
        #expect(state.phase == .idle)
        #expect(state.isSelecting == false)
        #expect(state.allowsScroll == true)
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

    // MARK: - forceActivate

    @Test("forceActivate transitions from pendingActivation to selecting")
    func forceActivateFromPending() {
        var state = ChartSelectionGestureState()
        let start = Date(timeIntervalSinceReferenceDate: 300)
        let initialScroll = Date(timeIntervalSinceReferenceDate: 280)

        _ = state.registerChange(
            at: start,
            translation: .zero,
            currentScrollPosition: initialScroll
        )

        #expect(state.phase == .pendingActivation)

        let result = state.forceActivate()

        #expect(result == .activated(restoreScrollPosition: initialScroll))
        #expect(state.phase == .selecting)
        #expect(state.isSelecting == true)
    }

    @Test("forceActivate returns inactive from idle state")
    func forceActivateFromIdle() {
        var state = ChartSelectionGestureState()

        #expect(state.phase == .idle)

        let result = state.forceActivate()

        #expect(result == .inactive)
        #expect(state.phase == .idle)
    }

    @Test("forceActivate returns inactive when cancelled")
    func forceActivateFromCancelled() {
        var state = ChartSelectionGestureState()
        let start = Date(timeIntervalSinceReferenceDate: 400)

        _ = state.registerChange(at: start, translation: .zero)
        _ = state.registerChange(
            at: start.addingTimeInterval(0.05),
            translation: CGSize(width: ChartSelectionInteraction.activationDistance + 5, height: 0)
        )

        #expect(state.isCancelled == true)

        let result = state.forceActivate()

        #expect(result == .inactive)
    }

    @Test("forceActivate returns inactive when already selecting")
    func forceActivateFromSelecting() {
        var state = ChartSelectionGestureState()
        let start = Date(timeIntervalSinceReferenceDate: 500)

        _ = state.registerChange(at: start, translation: .zero)
        _ = state.registerChange(
            at: start.addingTimeInterval(ChartSelectionInteraction.holdDuration + 0.01),
            translation: CGSize(width: 2, height: 1)
        )

        #expect(state.phase == .selecting)

        let result = state.forceActivate()

        #expect(result == .inactive)
        #expect(state.phase == .selecting)
    }

    @Test("registerChange returns updating after forceActivate")
    func registerChangeAfterForceActivate() {
        var state = ChartSelectionGestureState()
        let start = Date(timeIntervalSinceReferenceDate: 600)

        _ = state.registerChange(at: start, translation: .zero)
        _ = state.forceActivate()

        #expect(state.isSelecting == true)

        let update = state.registerChange(
            at: start.addingTimeInterval(0.5),
            translation: CGSize(width: 5, height: 3)
        )

        #expect(update == .updating)
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
