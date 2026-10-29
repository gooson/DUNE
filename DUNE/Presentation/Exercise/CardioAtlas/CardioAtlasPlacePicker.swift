import SwiftUI
import MapKit
import CoreLocation

struct CardioAtlasPlacePicker: View {
    let initialPlace: WorkoutPlace?
    let onSave: (WorkoutPlace?) -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var locator = CardioAtlasOneShotLocator()
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var selectedPlace: WorkoutPlace?
    @State private var searchTask: Task<Void, Never>?
    @State private var activeSearch: MKLocalSearch?
    @State private var isSearching = false
    @State private var searchMessage: String?
    @State private var showSaveError = false
    @State private var isSearchPresented = false
    @State private var selectionRevision = 0
    @State private var selectCurrentLocationWhenReady = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                List {
                    if let selectedPlace {
                        Section("Selected place") {
                            Label(selectedPlace.name, systemImage: "mappin.circle.fill")
                                .foregroundStyle(theme.accentColor)
                                .accessibilityIdentifier("cardio-atlas-place-selection")
                                .id("selected-place")
                            Map(initialPosition: .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: selectedPlace.latitude, longitude: selectedPlace.longitude),
                                latitudinalMeters: 800,
                                longitudinalMeters: 800
                            )), interactionModes: []) {
                                Marker(selectedPlace.name, coordinate: CLLocationCoordinate2D(
                                    latitude: selectedPlace.latitude,
                                    longitude: selectedPlace.longitude
                                ))
                            }
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .id(selectedPlace)
                            .accessibilityIdentifier("cardio-atlas-place-selection-map")
                        }
                    }

                    Section {
                        Button {
                            selectCurrentLocationWhenReady = true
                            locator.requestOnce()
                        } label: {
                            Label("Use current location", systemImage: "location")
                        }
                        .accessibilityIdentifier("cardio-atlas-place-current")
                        if locator.isLocating { ProgressView("Finding location") }
                        if let message = locator.message {
                            Text(message).foregroundStyle(DS.Color.textSecondary)
                        }
                        if initialPlace != nil || selectedPlace != nil {
                            Button("Remove place", role: .destructive) {
                                selectCurrentLocationWhenReady = false
                                selectedPlace = nil
                            }
                            .accessibilityIdentifier("cardio-atlas-place-remove")
                        }
                    }

                    Section("Search results") {
                        if isSearching {
                            ProgressView()
                        } else if let searchMessage {
                            Text(searchMessage).foregroundStyle(DS.Color.textSecondary)
                        } else if results.isEmpty {
                            Text("Search for a place or address")
                                .foregroundStyle(DS.Color.textSecondary)
                        } else {
                            ForEach(results, id: \.self) { item in
                                Button {
                                    let coordinate = item.placemark.coordinate
                                    selectPlace(WorkoutPlace(
                                        latitude: coordinate.latitude,
                                        longitude: coordinate.longitude,
                                        name: item.name ?? item.placemark.title ?? query,
                                        source: .manual
                                    ))
                                } label: {
                                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                        Text(item.name ?? item.placemark.title ?? "Place")
                                            .foregroundStyle(.primary)
                                        if let address = item.placemark.title, address != item.name {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundStyle(DS.Color.textSecondary)
                                        }
                                    }
                                }
                                .accessibilityIdentifier("cardio-atlas-place-result-\(item.name ?? "")")
                            }
                        }
                    }
                }
                .navigationTitle("Choose place")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, isPresented: $isSearchPresented,
                            placement: .navigationBarDrawer(displayMode: .always), prompt: "Place or address")
                .accessibilityIdentifier("cardio-atlas-place-picker")
                .onChange(of: query) { _, newValue in search(newValue) }
                .onReceive(locator.$coordinate) { coordinate in
                    if let coordinate, selectCurrentLocationWhenReady {
                        selectPlace(WorkoutPlace(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude,
                            name: String(localized: "Current location"),
                            source: .gps
                        ))
                    }
                    search(query)
                }
                .safeAreaInset(edge: .bottom) {
                    if selectedPlace != nil || initialPlace != nil {
                        Button(action: saveSelection) {
                            Text("Save")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.sm)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("cardio-atlas-place-confirm")
                        .padding(DS.Spacing.lg)
                        .background(.bar)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("cardio-atlas-place-cancel")
                    }
                }
                .onAppear {
                    selectedPlace = initialPlace
                    if !CardioAtlasPlaceSearchFixture.isEnabled {
                        locator.requestIfAuthorized()
                    }
                }
                .task(id: selectionRevision) {
                    guard selectionRevision > 0, selectedPlace != nil else { return }
                    // Wait for the selected row to enter the List before scrolling.
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        scrollProxy.scrollTo("selected-place", anchor: .top)
                    }
                }
                .alert("Could not save place", isPresented: $showSaveError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Please try again.")
                }
                .onDisappear {
                    searchTask?.cancel()
                    activeSearch?.cancel()
                    locator.cancel()
                }
            }
        }
    }

    private func selectPlace(_ place: WorkoutPlace?) {
        guard let place else { return }
        selectCurrentLocationWhenReady = false
        selectedPlace = place
        isSearchPresented = false
        selectionRevision += 1
    }

    private func saveSelection() {
        if onSave(selectedPlace) {
            dismiss()
        } else {
            showSaveError = true
        }
    }

    private func search(_ text: String) {
        searchTask?.cancel()
        activeSearch?.cancel()
        activeSearch = nil
        results = []
        searchMessage = nil
        guard let trimmed = CardioAtlasPlaceSearch.normalizedQuery(text) else {
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, trimmed == CardioAtlasPlaceSearch.normalizedQuery(query) else { return }
            let reference = CardioAtlasPlaceSearch.referenceCoordinate(
                current: CardioAtlasPlaceSearchFixture.isEnabled
                    ? CardioAtlasPlaceSearchFixture.coordinate : locator.coordinate,
                initialPlace: initialPlace
            )
            if CardioAtlasPlaceSearchFixture.isEnabled {
                results = CardioAtlasPlaceSearch.sorted(CardioAtlasPlaceSearchFixture.results, near: reference, matching: trimmed)
                isSearching = false
                searchMessage = results.isEmpty ? String(localized: "No matching places found") : nil
                return
            }
            let search: MKLocalSearch
            if CardioAtlasPlaceSearch.usesInitialConsonants(trimmed) {
                if CardioAtlasPlaceSearch.expandedInitialQuery(trimmed) != nil {
                    search = MKLocalSearch(request: CardioAtlasPlaceSearch.request(query: trimmed, near: reference))
                } else if let reference {
                    search = MKLocalSearch(request: CardioAtlasPlaceSearch.nearbyRequest(near: reference))
                } else {
                    searchMessage = String(localized: "For initial-consonant search, use current location or enter a full place name.")
                    isSearching = false
                    return
                }
            } else {
                search = MKLocalSearch(request: CardioAtlasPlaceSearch.request(query: trimmed, near: reference))
            }
            activeSearch = search
            do {
                let response = try await search.start()
                guard !Task.isCancelled, trimmed == CardioAtlasPlaceSearch.normalizedQuery(query) else { return }
                results = CardioAtlasPlaceSearch.sorted(response.mapItems, near: reference, matching: trimmed)
                searchMessage = results.isEmpty ? String(localized: "No matching places found") : nil
            } catch {
                guard !Task.isCancelled else { return }
                searchMessage = String(localized: "Places could not be loaded. Try another search.")
            }
            isSearching = false
            activeSearch = nil
        }
    }
}

@MainActor
private final class CardioAtlasOneShotLocator: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var isLocating = false
    @Published private(set) var message: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            requestOnce()
        default:
            break
        }
    }

    func requestOnce() {
        message = nil
        coordinate = nil
        switch manager.authorizationStatus {
        case .denied, .restricted:
            message = String(localized: "Location access is off. Choose a place from search.")
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isLocating = true
            manager.requestLocation()
        @unknown default:
            message = String(localized: "Location is unavailable. Choose a place from search.")
        }
    }

    func cancel() {
        manager.stopUpdatingLocation()
        isLocating = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isLocating else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted:
            isLocating = false
            message = String(localized: "Location access is off. Choose a place from search.")
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLocating = false
        manager.stopUpdatingLocation()
        coordinate = locations.last(where: {
            $0.horizontalAccuracy >= 0
                && (-10...120).contains(-$0.timestamp.timeIntervalSinceNow)
                && CLLocationCoordinate2DIsValid($0.coordinate)
        })?.coordinate
        if coordinate == nil {
            message = String(localized: "Location is unavailable. Choose a place from search.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        message = String(localized: "Location is unavailable. Choose a place from search.")
    }
}

/// Opt-in synthetic results keep UI regression tests independent of MapKit networking.
private enum CardioAtlasPlaceSearchFixture {
    static var isEnabled: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--uitesting") && arguments.contains("--ui-cardio-place-search-fixture")
        #else
        return false
        #endif
    }

    static let coordinate = CLLocationCoordinate2D(latitude: 37.5445, longitude: 127.0374)

    static var results: [MKMapItem] {
        (1...24).reversed().map { index in
            let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
                latitude: coordinate.latitude + Double(index) * 0.001,
                longitude: coordinate.longitude
            )))
            item.name = "Atlas Test Gym \(index)"
            return item
        } + ["헬스플러스", "헬스클럽", "서울숲 수영장", "Danubius Hotel Helia"].enumerated().map { index, name in
            let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
                latitude: coordinate.latitude + Double(index + 1) * 0.001,
                longitude: coordinate.longitude + 0.001
            )))
            item.name = name
            return item
        }
    }
}

#Preview {
    CardioAtlasPlacePicker(initialPlace: nil) { _ in true }
}
