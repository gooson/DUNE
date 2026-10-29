import Foundation
import SwiftUI
import MapKit
import Testing
@testable import DUNE

@Suite("Cardio Atlas share rendering")
@MainActor
struct CardioAtlasShareRenderingTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("A short route crossing the date line keeps a local, valid map region")
    func dateLineGeometry() {
        let coordinates = [CLLocationCoordinate2D(latitude: 37, longitude: 179.999),
                           CLLocationCoordinate2D(latitude: 37.001, longitude: -179.999)]
        let region = CardioAtlasRouteGeometry.region(for: [coordinates], fallback: coordinates[0])
        #expect(region.span.longitudeDelta < 0.01)
        #expect(abs(region.center.longitude) > 179)
        let delta = CardioAtlasRouteGeometry.longitudeDelta(from: region.center.longitude, to: coordinates[0].longitude)
        #expect(abs(delta) < region.span.longitudeDelta / 2)
    }

    @Test("Private Atlas and Signature cards render a positive-size image without a map snapshot")
    func privateCardsRender() throws {
        let session = CardioAtlasSession(
            id: "render-check", activityType: .running, date: date,
            duration: 1_200, distanceMeters: 2_000
        )
        let hidden = routeLocation.shareLocation(showPlace: false, trimDistanceMeters: 300)
        #expect(hidden.route.isEmpty)
        #expect(hidden.place == nil)
        let excludedStatus = CardioAtlasShareLocationStatus.resolve(
            source: routeLocation, published: hidden, showPlace: false, trimEnds: true
        )
        #expect(excludedStatus == .excluded)
        let missingStatus = CardioAtlasShareLocationStatus.resolve(
            source: WorkoutLocationPayload(), published: WorkoutLocationPayload(),
            showPlace: false, trimEnds: true
        )
        #expect(missingStatus == .missing)
        let trimmed = routeLocation.shareLocation(showPlace: true, trimDistanceMeters: 300)
        let trimmedStatus = CardioAtlasShareLocationStatus.resolve(
            source: routeLocation, published: trimmed, showPlace: true, trimEnds: true
        )
        #expect(trimmedStatus == .trimmed)

        for style in [CardioAtlasShareStyle.atlas, .signature] {
            let card = CardioAtlasShareCard(
                session: session, location: hidden, style: style,
                mapImage: nil, snapshotUnavailable: false, locationStatus: .excluded,
                journeySummary: nil, passportSummary: nil
            )
            let renderer = ImageRenderer(content: card.frame(width: 400))
            renderer.proposedSize = ProposedViewSize(width: 400, height: nil)
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            #expect(image.size.width >= 400)
            #expect(image.size.height > 200)
        }
    }

    @Test("Pace uses measured intervals and preserves a recorded pause boundary")
    func measuredPaceAndSegmentBoundary() {
        let points = routeLocation.route
        let segments = CardioAtlasRouteGeometry.segments(points)
        #expect(segments.count == 2)

        let pace = CardioAtlasPaceSegments.from(points)
        #expect(pace.count == 2)
        #expect(pace.allSatisfy { $0.metersPerSecond > 0 })
        #expect(CardioAtlasPaceSegments.from([]).isEmpty)
    }

    @Test("One-hertz GPS samples remain eligible without bridging a pause")
    func oneHertzPace() {
        let points: [WorkoutRoutePoint] = (0..<60).compactMap { (index: Int) -> WorkoutRoutePoint? in
            let latitude = 37.54 + Double(index < 30 ? index : index + 100) * 0.000025
            let timestamp = date.addingTimeInterval(Double(index < 30 ? index : index + 180))
            return WorkoutRoutePoint(
                latitude: latitude, longitude: 127.04,
                timestamp: timestamp, startsNewSegment: index == 30
            )
        }
        let pace = CardioAtlasPaceSegments.from(points)
        #expect(pace.count == 58)
        let hasInvalidSpeed = pace.contains { $0.metersPerSecond <= 0 || $0.metersPerSecond > 50 }
        #expect(!hasInvalidSpeed)
        let beforePauseLatitude = points[29].latitude
        let afterPauseLatitude = points[30].latitude
        let containsBridge = pace.contains { segment in
            segment.start.latitude == beforePauseLatitude && segment.end.latitude == afterPauseLatitude
        }
        #expect(!containsBridge)
    }

    @Test("Measured fast cycling interval is retained")
    func fastCyclingInterval() throws {
        let first = try #require(WorkoutRoutePoint(
            latitude: 37.54, longitude: 127.04, timestamp: date
        ))
        let second = try #require(WorkoutRoutePoint(
            latitude: 37.54025, longitude: 127.04, timestamp: date.addingTimeInterval(1)
        ))
        let pace = CardioAtlasPaceSegments.from([first, second])
        #expect(pace.count == 1)
        #expect(pace[0].metersPerSecond > 15)
        #expect(pace[0].metersPerSecond < 50)
    }

    private var routeLocation: WorkoutLocationPayload {
        let samples: [(Double, Double, TimeInterval, Bool)] = [
            (37.5460, 127.0400, 0, false),
            (37.5465, 127.0400, 60, false),
            (37.5470, 127.0405, 600, true),
            (37.5475, 127.0405, 660, false),
        ]
        let points = samples.compactMap { latitude, longitude, seconds, startsNewSegment in
            WorkoutRoutePoint(
                latitude: latitude, longitude: longitude,
                timestamp: date.addingTimeInterval(seconds),
                startsNewSegment: startsNewSegment
            )
        }
        return WorkoutLocationPayload(
            isIndoor: false, route: points,
            place: WorkoutPlace(latitude: 37.5460, longitude: 127.0400, name: "Test park", source: .manual)
        )
    }
}
