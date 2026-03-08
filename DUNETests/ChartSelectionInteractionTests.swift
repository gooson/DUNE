import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import DUNE

@Suite("ChartSelectionInteraction")
struct ChartSelectionInteractionTests {
    @Test("beginSelection transitions from idle to selecting and captures scroll position")
    func beginSelectionTransitionsToSelecting() {
        var state = ChartSelectionGestureState()
        let scrollPos = Date(timeIntervalSinceReferenceDate: 100)

        #expect(state.phase == .idle)
        #expect(state.allowsScroll == true)
        #expect(state.isSelecting == false)

        state.beginSelection(scrollPosition: scrollPos)

        #expect(state.phase == .selecting)
        #expect(state.isSelecting == true)
        #expect(state.allowsScroll == false)
        #expect(state.initialScrollPosition == scrollPos)
    }

    @Test("beginSelection is idempotent — second call does not overwrite initialScrollPosition")
    func beginSelectionIdempotent() {
        var state = ChartSelectionGestureState()
        let firstScroll = Date(timeIntervalSinceReferenceDate: 100)
        let secondScroll = Date(timeIntervalSinceReferenceDate: 200)

        state.beginSelection(scrollPosition: firstScroll)
        state.beginSelection(scrollPosition: secondScroll)

        #expect(state.initialScrollPosition == firstScroll)
        #expect(state.isSelecting == true)
    }

    @Test("reset returns state to idle with nil scroll position")
    func resetReturnsToIdle() {
        var state = ChartSelectionGestureState()
        state.beginSelection(scrollPosition: Date(timeIntervalSinceReferenceDate: 100))

        #expect(state.isSelecting == true)

        state.reset()

        #expect(state.phase == .idle)
        #expect(state.isSelecting == false)
        #expect(state.allowsScroll == true)
        #expect(state.initialScrollPosition == nil)
    }

    @Test("clearSelection resets state and selected date")
    @MainActor
    func clearSelectionResetsBindings() {
        var state = ChartSelectionGestureState()
        state.beginSelection(scrollPosition: Date(timeIntervalSinceReferenceDate: 100))
        var selectedDate: Date? = Date(timeIntervalSinceReferenceDate: 200)

        let stateBinding = Binding(
            get: { state },
            set: { state = $0 }
        )
        let selectedBinding = Binding(
            get: { selectedDate },
            set: { selectedDate = $0 }
        )

        ChartSelectionInteraction.clearSelection(
            selectionState: stateBinding,
            selectedDate: selectedBinding
        )

        #expect(state.phase == .idle)
        #expect(state.initialScrollPosition == nil)
        #expect(selectedDate == nil)
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
