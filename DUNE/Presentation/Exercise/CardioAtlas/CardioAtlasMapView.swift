import SwiftUI
import MapKit

/// Displays only coordinates recorded for this workout. A missing location has no map tiles.
struct CardioAtlasMapView: View {
    let location: WorkoutLocationPayload
    var expanded = false

    @Environment(\.appTheme) private var theme
    @State private var showExpandedMap = false

    private var segments: [[CLLocationCoordinate2D]] {
        CardioAtlasRouteGeometry.segments(location.route)
    }

    private var coordinate: CLLocationCoordinate2D? {
        if let first = segments.first?.first { return first }
        guard let place = location.place else { return nil }
        return CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let coordinate {
                Map(initialPosition: .region(CardioAtlasRouteGeometry.region(for: segments, fallback: coordinate))) {
                    ForEach(segments.indices, id: \.self) { index in
                        MapPolyline(coordinates: segments[index])
                            .stroke(theme.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                    if segments.isEmpty, let place = location.place {
                        Annotation(place.name, coordinate: coordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundStyle(theme.accentColor)
                                .accessibilityLabel(place.name)
                        }
                    }
                }
                .mapControls { MapCompass(); MapScaleView() }
                .frame(height: expanded ? 420 : 240)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(alignment: .topTrailing) {
                    if !expanded {
                        Button {
                            showExpandedMap = true
                        } label: {
                            Label("Expand map", systemImage: "arrow.up.left.and.arrow.down.right")
                                .labelStyle(.iconOnly)
                                .padding(DS.Spacing.sm)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .padding(DS.Spacing.sm)
                        .accessibilityIdentifier("cardio-atlas-expand-map")
                    }
                }
                .sheet(isPresented: $showExpandedMap) {
                    NavigationStack {
                        CardioAtlasMapView(location: location, expanded: true)
                            .padding(DS.Spacing.lg)
                            .navigationTitle("Workout map")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showExpandedMap = false }
                                }
                            }
                    }
                }
            } else {
                VStack {
                    ContentUnavailableView("Location not recorded", systemImage: "map", description: Text("Workout metrics are still available."))
                        .accessibilityIdentifier("cardio-atlas-map-empty")
                }
                .frame(maxWidth: .infinity)
                .frame(height: expanded ? 420 : 240)
                .background(DS.Color.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cardio-atlas-map")
    }
}

enum CardioAtlasRouteGeometry {
    static func segments(_ points: [WorkoutRoutePoint]) -> [[CLLocationCoordinate2D]] {
        var result: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = []
        for point in points {
            if point.startsNewSegment, !current.isEmpty {
                result.append(current)
                current = []
            }
            current.append(CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    static func region(
        for segments: [[CLLocationCoordinate2D]],
        fallback: CLLocationCoordinate2D
    ) -> MKCoordinateRegion {
        let coordinates = segments.flatMap { $0 }
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(center: fallback, latitudinalMeters: 800, longitudinalMeters: 800)
        }
        let latitudes = coordinates.map(\.latitude)
        let referenceLongitude = coordinates.first?.longitude ?? fallback.longitude
        let longitudes = coordinates.map {
            referenceLongitude + longitudeDelta(from: referenceLongitude, to: $0.longitude)
        }
        let minLat = latitudes.min() ?? fallback.latitude
        let maxLat = latitudes.max() ?? fallback.latitude
        let minLon = longitudes.min() ?? fallback.longitude
        let maxLon = longitudes.max() ?? fallback.longitude
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: longitudeDelta(from: 0, to: (minLon + maxLon) / 2)
            ),
            span: MKCoordinateSpan(
                latitudeDelta: min(180, max(0.006, (maxLat - minLat) * 1.35)),
                longitudeDelta: min(360, max(0.006, (maxLon - minLon) * 1.35))
            )
        )
    }

    static func longitudeDelta(from origin: Double, to destination: Double) -> Double {
        (destination - origin + 540).truncatingRemainder(dividingBy: 360) - 180
    }
}

#Preview("Missing location") {
    CardioAtlasMapView(location: WorkoutLocationPayload())
}
