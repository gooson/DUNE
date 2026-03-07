import Charts
import CoreGraphics
import Foundation

enum ChartSelectionOverlayEdge: Sendable {
    case above
    case below
}

struct ChartSelectionOverlayLayout: Equatable, Sendable {
    let center: CGPoint
    let edge: ChartSelectionOverlayEdge
}

struct ChartSelectionGestureState: Sendable {
    private(set) var startTime: Date?
    private(set) var isActive = false
    private(set) var isCancelled = false

    mutating func registerChange(
        at time: Date,
        translation: CGSize,
        holdDuration: TimeInterval = ChartSelectionInteraction.holdDuration,
        activationDistance: CGFloat = ChartSelectionInteraction.activationDistance
    ) -> Bool {
        if startTime == nil {
            startTime = time
        }

        guard isCancelled == false, let startTime else {
            return false
        }

        if isActive == false {
            if translation.magnitude > activationDistance {
                isCancelled = true
                return false
            }

            if time.timeIntervalSince(startTime) >= holdDuration {
                isActive = true
            }
        }

        return isActive
    }

    mutating func reset() {
        self = ChartSelectionGestureState()
    }
}

enum ChartSelectionInteraction {
    static let holdDuration: TimeInterval = 0.18
    static let activationDistance: CGFloat = 10
    static let overlaySpacing: CGFloat = 12
    static let horizontalMargin: CGFloat = 12
    static let topMargin: CGFloat = 8
    static let bottomMargin: CGFloat = 8
    static let defaultOverlaySize = CGSize(width: 156, height: 34)

    static func resolvedDate(
        at location: CGPoint,
        proxy: ChartProxy,
        plotFrame: CGRect
    ) -> Date? {
        guard plotFrame.width > 1 else { return nil }

        let epsilon: CGFloat = 0.5
        let clampedX = min(
            max(location.x, plotFrame.minX + epsilon),
            plotFrame.maxX - epsilon
        )

        return proxy.value(atX: clampedX - plotFrame.minX, as: Date.self)
    }

    static func nearestPoint<T>(
        to targetDate: Date,
        in points: [T],
        date: (T) -> Date
    ) -> T? {
        points.min(by: {
            abs(date($0).timeIntervalSince(targetDate)) < abs(date($1).timeIntervalSince(targetDate))
        })
    }

    static func nearestPoint<T>(
        to targetDate: Date,
        in points: [T],
        date dateKeyPath: KeyPath<T, Date>
    ) -> T? {
        nearestPoint(to: targetDate, in: points) { point in
            point[keyPath: dateKeyPath]
        }
    }

    static func anchor(
        xPosition: CGFloat?,
        yPosition: CGFloat?,
        plotFrame: CGRect
    ) -> CGPoint? {
        guard let xPosition, let yPosition else { return nil }

        return CGPoint(
            x: plotFrame.minX + xPosition,
            y: plotFrame.minY + yPosition
        )
    }

    static func overlayLayout(
        anchor: CGPoint,
        overlaySize: CGSize,
        chartSize: CGSize,
        plotFrame: CGRect,
        spacing: CGFloat = overlaySpacing,
        horizontalMargin: CGFloat = horizontalMargin,
        topMargin: CGFloat = topMargin,
        bottomMargin: CGFloat = bottomMargin
    ) -> ChartSelectionOverlayLayout {
        let resolvedOverlaySize = overlaySize == .zero ? defaultOverlaySize : overlaySize
        let halfWidth = resolvedOverlaySize.width / 2
        let halfHeight = resolvedOverlaySize.height / 2

        let minCenterX = horizontalMargin + halfWidth
        let maxCenterX = max(minCenterX, chartSize.width - horizontalMargin - halfWidth)
        let centerX = min(max(anchor.x, minCenterX), maxCenterX)

        let preferredAboveY = anchor.y - spacing - halfHeight
        let preferredBelowY = anchor.y + spacing + halfHeight

        let topLimit = topMargin + halfHeight
        let bottomLimit = plotFrame.maxY - bottomMargin - halfHeight
        let lowerBound = min(topLimit, bottomLimit)
        let upperBound = max(topLimit, bottomLimit)

        if preferredAboveY >= topLimit {
            return ChartSelectionOverlayLayout(
                center: CGPoint(x: centerX, y: min(preferredAboveY, upperBound)),
                edge: .above
            )
        }

        if preferredBelowY <= bottomLimit {
            return ChartSelectionOverlayLayout(
                center: CGPoint(x: centerX, y: max(preferredBelowY, lowerBound)),
                edge: .below
            )
        }

        let clampedY = min(max(preferredAboveY, lowerBound), upperBound)

        return ChartSelectionOverlayLayout(
            center: CGPoint(x: centerX, y: clampedY),
            edge: clampedY > anchor.y ? .below : .above
        )
    }
}

private extension CGSize {
    var magnitude: CGFloat {
        sqrt((width * width) + (height * height))
    }
}
