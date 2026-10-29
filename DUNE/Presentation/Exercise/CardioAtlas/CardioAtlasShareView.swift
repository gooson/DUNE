import SwiftUI
import MapKit
import UIKit

struct CardioAtlasShareView: View {
    let session: CardioAtlasSession
    let location: WorkoutLocationPayload
    let journeySummary: String?
    let passportSummary: String?

    @Environment(\.displayScale) private var displayScale
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var style: CardioAtlasShareStyle = .atlas
    @State private var showPlace = false
    @State private var trimEnds = true
    @State private var includeJourney = true
    @State private var includePassport = true
    @State private var mapImage: UIImage?
    @State private var shareImage: UIImage?
    @State private var isRendering = false
    @State private var snapshotUnavailable = false
    @State private var imageUnavailable = false
    @State private var snapshotter: MKMapSnapshotter?
    @State private var renderID = UUID()

    private var publishedLocation: WorkoutLocationPayload {
        location.shareLocation(showPlace: showPlace, trimDistanceMeters: trimEnds ? 300 : 0)
    }

    private var hasPaceSegments: Bool {
        !CardioAtlasPaceSegments.from(location.route).isEmpty
    }

    private var locationStatus: CardioAtlasShareLocationStatus {
        CardioAtlasShareLocationStatus.resolve(
            source: location,
            published: publishedLocation,
            showPlace: showPlace,
            trimEnds: trimEnds
        )
    }

    private var renderKey: String {
        "\(style.rawValue)-\(showPlace)-\(trimEnds)-\(includeJourney)-\(includePassport)-\(location.hashValue)-\(session.id)-\(colorScheme)-\(locale.identifier)-\(dynamicTypeSize)-\(theme)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                stylePicker

                CardioAtlasShareCard(
                    session: session,
                    location: publishedLocation,
                    style: style,
                    mapImage: mapImage,
                    snapshotUnavailable: snapshotUnavailable,
                    locationStatus: locationStatus,
                    journeySummary: includeJourney ? journeySummary : nil,
                    passportSummary: includePassport ? passportSummary : nil
                )
                .frame(maxWidth: 410)
                .accessibilityIdentifier("cardio-atlas-share-preview")

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Toggle("Include location on card", isOn: $showPlace)
                        .accessibilityIdentifier("cardio-atlas-share-location")
                    if showPlace, location.route.count >= 2 {
                        Toggle("Hide first and last 300 m", isOn: $trimEnds)
                            .accessibilityIdentifier("cardio-atlas-share-trim")
                        if trimEnds, location.place != nil {
                            Text("Selected place stays visible.")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    if journeySummary != nil {
                        Toggle("Include Journey", isOn: $includeJourney)
                            .accessibilityIdentifier("cardio-atlas-share-journey")
                    }
                    if passportSummary != nil {
                        Toggle("Include Passport", isOn: $includePassport)
                            .accessibilityIdentifier("cardio-atlas-share-passport")
                    }
                }
                .tint(theme.accentColor)
                .frame(maxWidth: 410)

                if isRendering { ProgressView("Preparing image") }
                if snapshotUnavailable {
                    Button("Retry map") { Task { await renderCard() } }
                        .disabled(isRendering)
                        .accessibilityIdentifier("cardio-atlas-share-retry-map")
                }
                if imageUnavailable {
                    Text("Image could not be prepared")
                        .foregroundStyle(DS.Color.textSecondary)
                    Button("Retry image") { Task { await renderCard() } }
                        .disabled(isRendering)
                        .accessibilityIdentifier("cardio-atlas-share-retry-image")
                }
                if let shareImage {
                    ShareLink(
                        item: Image(uiImage: shareImage),
                        preview: SharePreview(session.activityType.displayName, image: Image(uiImage: shareImage))
                    ) {
                        Label("Share image", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accentColor)
                    .frame(maxWidth: 410)
                    .accessibilityIdentifier("cardio-atlas-share-action")
                }
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Share workout")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: renderKey) { await renderCard() }
        .onDisappear { snapshotter?.cancel() }
    }

    private var stylePicker: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(CardioAtlasShareStyle.allCases) { option in
                Button {
                    style = option
                } label: {
                    VStack(spacing: DS.Spacing.xs) {
                        Image(systemName: option.symbol)
                            .font(.title3)
                        Text(option.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 62)
                }
                .buttonStyle(.bordered)
                .tint(style == option ? theme.accentColor : DS.Color.textSecondary)
                .disabled(option == .paceRibbon && !hasPaceSegments)
                .accessibilityIdentifier("style-cardio-atlas-\(option.rawValue)")
            }
        }
        .frame(maxWidth: 410)
    }

    @MainActor
    private func renderCard() async {
        snapshotter?.cancel()
        snapshotter = nil
        shareImage = nil
        mapImage = nil
        snapshotUnavailable = false
        imageUnavailable = false
        isRendering = true
        let expectedID = UUID()
        renderID = expectedID
        let publicLocation = publishedLocation
        var snapshot: UIImage?
        if showPlace, style != .signature,
           let coordinate = CardioAtlasRouteGeometry.segments(publicLocation.route).first?.first
                ?? publicLocation.place.map({ CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }) {
            let options = MKMapSnapshotter.Options()
            options.region = CardioAtlasRouteGeometry.region(
                for: CardioAtlasRouteGeometry.segments(publicLocation.route), fallback: coordinate
            )
            options.size = CGSize(width: 800, height: 500)
            options.scale = 2
            options.mapType = .standard
            options.traitCollection = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
            let current = MKMapSnapshotter(options: options)
            snapshotter = current
            do {
                let rendered = try await current.start()
                guard !Task.isCancelled, renderID == expectedID else { return }
                snapshot = CardioAtlasSnapshotDrawing.draw(
                    rendered,
                    location: publicLocation,
                    pace: style == .paceRibbon,
                    accent: UIColor(theme.accentColor)
                )
            } catch {
                guard !Task.isCancelled, renderID == expectedID else { return }
                snapshotUnavailable = true
                isRendering = false
                snapshotter = nil
                return
            }
        }
        guard !Task.isCancelled, renderID == expectedID else { return }
        mapImage = snapshot
        let card = CardioAtlasShareCard(
            session: session,
            location: publicLocation,
            style: style,
            mapImage: snapshot,
            snapshotUnavailable: false,
            locationStatus: locationStatus,
            journeySummary: includeJourney ? journeySummary : nil,
            passportSummary: includePassport ? passportSummary : nil
        )
        let renderer = ImageRenderer(content: card.frame(width: 400)
            .environment(\.appTheme, theme)
            .environment(\.colorScheme, colorScheme)
            .environment(\.locale, locale)
            .environment(\.dynamicTypeSize, dynamicTypeSize))
        renderer.proposedSize = ProposedViewSize(width: 400, height: nil)
        renderer.scale = max(2, displayScale)
        guard !Task.isCancelled, renderID == expectedID else { return }
        if let image = renderer.uiImage {
            shareImage = image
        } else {
            imageUnavailable = true
        }
        isRendering = false
        snapshotter = nil
    }
}

enum CardioAtlasShareStyle: String, CaseIterable, Identifiable {
    case atlas, paceRibbon, signature

    var id: String { rawValue }
    var title: String {
        switch self {
        case .atlas: String(localized: "Atlas")
        case .paceRibbon: String(localized: "Pace Ribbon")
        case .signature: String(localized: "Signature")
        }
    }
    var symbol: String {
        switch self {
        case .atlas: "map"
        case .paceRibbon: "point.topleft.down.to.point.bottomright.curvepath"
        case .signature: "scribble.variable"
        }
    }
}

enum CardioAtlasShareLocationStatus: Equatable {
    case available
    case missing
    case excluded
    case trimmed

    static func resolve(
        source: WorkoutLocationPayload,
        published: WorkoutLocationPayload,
        showPlace: Bool,
        trimEnds: Bool
    ) -> Self {
        if source.route.isEmpty, source.place == nil { return .missing }
        if !showPlace { return .excluded }
        if trimEnds, !source.route.isEmpty, published.route.isEmpty { return .trimmed }
        return .available
    }

    var message: String? {
        switch self {
        case .available: nil
        case .missing: String(localized: "Location not recorded")
        case .excluded: String(localized: "Location excluded")
        case .trimmed: String(localized: "Route hidden by endpoint trimming")
        }
    }
}

struct CardioAtlasShareCard: View {
    let session: CardioAtlasSession
    let location: WorkoutLocationPayload
    let style: CardioAtlasShareStyle
    let mapImage: UIImage?
    let snapshotUnavailable: Bool
    let locationStatus: CardioAtlasShareLocationStatus
    let journeySummary: String?
    let passportSummary: String?

    @Environment(\.appTheme) private var theme

    private var distance: String? {
        guard let meters = session.distanceMeters, meters.isFinite, meters > 0 else { return nil }
        return (meters / 1_000).formatted(.number.precision(.fractionLength(1))) + " km"
    }

    private var duration: String {
        let seconds = session.duration.isFinite ? max(0, Int(session.duration.rounded())) : 0
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack {
                Text("DUNE")
                    .font(.caption.weight(.bold))
                    .tracking(3)
                Spacer()
                Text(session.date, format: .dateTime.year().month(.abbreviated).day())
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Text(session.activityType.displayName)
                .font(.system(.largeTitle, design: .serif, weight: .medium))
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            if style == .signature {
                signatureVisual
            } else if let mapImage {
                Image(uiImage: mapImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 250)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            } else if snapshotUnavailable {
                Label("Map could not be loaded", systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(DS.Color.surfacePrimary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            } else if let message = locationStatus.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(DS.Color.surfacePrimary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            if mapImage != nil {
                Text("Map data © Apple")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if (mapImage != nil || style == .signature), let message = locationStatus.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(distance ?? duration)
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(distance == nil ? "Duration" : "Distance")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                Spacer()
                if distance != nil {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        Text(duration).font(.title3.weight(.medium))
                        Text("Duration").font(.caption).foregroundStyle(DS.Color.textSecondary)
                    }
                }
            }

            if let place = location.place {
                Label(place.name, systemImage: "mappin")
                    .font(.caption)
                    .foregroundStyle(theme.accentColor)
            }
            if let journeySummary {
                Label(journeySummary, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.caption)
            }
            if let passportSummary {
                Label(passportSummary, systemImage: "seal")
                    .font(.caption)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(theme.accentColor.opacity(DS.Opacity.border)))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    @ViewBuilder
    private var signatureVisual: some View {
        let segments = CardioAtlasRouteGeometry.segments(location.route)
        if segments.contains(where: { $0.count > 1 }) {
            GeometryReader { geometry in
                Canvas { context, size in
                    let all = segments.flatMap { $0 }
                    let region = CardioAtlasRouteGeometry.region(for: segments, fallback: all[0])
                    for segment in segments where segment.count > 1 {
                        var path = Path()
                        for (index, coordinate) in segment.enumerated() {
                            let x = CardioAtlasRouteGeometry.longitudeDelta(
                                from: region.center.longitude, to: coordinate.longitude
                            ) / region.span.longitudeDelta + 0.5
                            let y = 0.5 - (coordinate.latitude - region.center.latitude) / region.span.latitudeDelta
                            let point = CGPoint(x: x * size.width, y: y * size.height)
                            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                        context.stroke(path, with: .color(theme.accentColor), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(height: 180)
            .accessibilityLabel("Recorded route silhouette")
        }
    }
}

struct CardioAtlasPaceSegments {
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    let metersPerSecond: Double

    static func from(_ points: [WorkoutRoutePoint]) -> [Self] {
        guard points.count > 1 else { return [] }
        var result: [Self] = []
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            guard !current.startsNewSegment else { continue }
            let duration = current.timestamp.timeIntervalSince(previous.timestamp)
            guard duration >= 1, duration <= 300 else { continue }
            let start = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
            let end = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let distance = start.distance(from: end)
            guard distance >= max(1, duration * 0.25), distance / duration <= 50 else { continue }
            result.append(Self(start: start.coordinate, end: end.coordinate, metersPerSecond: distance / duration))
        }
        return result
    }
}

private enum CardioAtlasSnapshotDrawing {
    @MainActor
    static func draw(
        _ snapshot: MKMapSnapshotter.Snapshot,
        location: WorkoutLocationPayload,
        pace: Bool,
        accent: UIColor
    ) -> UIImage {
        let size = snapshot.image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let paceSegments = pace ? CardioAtlasPaceSegments.from(location.route) : []
        let speedRange = paceSegments.reduce((minimum: Double.infinity, maximum: 0.0)) { bounds, segment in
            (min(bounds.minimum, segment.metersPerSecond), max(bounds.maximum, segment.metersPerSecond))
        }
        return renderer.image { context in
            snapshot.image.draw(at: .zero)
            let graphics = context.cgContext
            graphics.setLineCap(.round)
            graphics.setLineJoin(.round)
            graphics.setLineWidth(9)
            if pace, !paceSegments.isEmpty {
                for segment in paceSegments {
                    let fraction = (segment.metersPerSecond - speedRange.minimum)
                        / max(0.1, speedRange.maximum - speedRange.minimum)
                    graphics.setStrokeColor((fraction < 0.5 ? accent : UIColor(DS.Color.activity)).cgColor)
                    graphics.move(to: snapshot.point(for: segment.start))
                    graphics.addLine(to: snapshot.point(for: segment.end))
                    graphics.strokePath()
                }
            } else {
                graphics.setStrokeColor(accent.cgColor)
                for segment in CardioAtlasRouteGeometry.segments(location.route) where segment.count > 1 {
                    graphics.addLines(between: segment.map(snapshot.point(for:)))
                    graphics.strokePath()
                }
            }
            if location.route.isEmpty, let place = location.place {
                let point = snapshot.point(for: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                graphics.setFillColor(accent.cgColor)
                graphics.fillEllipse(in: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18))
            }
        }
    }
}

#Preview {
    NavigationStack {
        CardioAtlasShareView(
            session: CardioAtlasSession(
                id: "preview", activityType: .running, date: .now,
                duration: 1_800, distanceMeters: nil
            ),
            location: WorkoutLocationPayload(),
            journeySummary: nil,
            passportSummary: nil
        )
    }
}
