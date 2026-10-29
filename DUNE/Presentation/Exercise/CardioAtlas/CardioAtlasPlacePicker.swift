import SwiftUI
import MapKit
import CoreLocation

struct CardioAtlasPlacePicker: View {
    let initialPlace: WorkoutPlace?
    let onSave: (WorkoutPlace?) -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @StateObject private var locator = CardioAtlasOneShotLocator()
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var selectedPlace: WorkoutPlace?
    @State private var searchTask: Task<Void, Never>?
    @State private var activeSearch: MKLocalSearch?
    @State private var isSearching = false
    @State private var searchMessage: String?
    @State private var showSaveError = false

    var body: some View {
        NavigationStack {
            List {
                if let selectedPlace {
                    Section("Selected place") {
                        Label(selectedPlace.name, systemImage: "mappin.circle.fill")
                            .foregroundStyle(theme.accentColor)
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: selectedPlace.latitude, longitude: selectedPlace.longitude),
                            latitudinalMeters: 800,
                            longitudinalMeters: 800
                        ))) {
                            Marker(selectedPlace.name, coordinate: CLLocationCoordinate2D(
                                latitude: selectedPlace.latitude,
                                longitude: selectedPlace.longitude
                            ))
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                }

                Section {
                    Button {
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
                                selectedPlace = WorkoutPlace(
                                    latitude: coordinate.latitude,
                                    longitude: coordinate.longitude,
                                    name: item.name ?? item.placemark.title ?? query,
                                    source: .manual
                                )
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
                        }
                    }
                }
            }
            .navigationTitle("Choose place")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Place or address")
            .accessibilityIdentifier("cardio-atlas-place-picker")
            .onChange(of: query) { _, newValue in search(newValue) }
            .onReceive(locator.$coordinate) { coordinate in
                guard let coordinate else { return }
                selectedPlace = WorkoutPlace(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    name: String(localized: "Current location"),
                    source: .gps
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cardio-atlas-place-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if onSave(selectedPlace) {
                            dismiss()
                        } else {
                            showSaveError = true
                        }
                    }
                    .accessibilityIdentifier("cardio-atlas-place-save")
                }
            }
            .onAppear { selectedPlace = initialPlace }
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

    private func search(_ text: String) {
        searchTask?.cancel()
        activeSearch?.cancel()
        results = []
        searchMessage = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed
            request.resultTypes = [.pointOfInterest, .address]
            let search = MKLocalSearch(request: request)
            activeSearch = search
            do {
                let response = try await search.start()
                guard !Task.isCancelled, trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
                results = response.mapItems
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
    }

    func requestOnce() {
        message = nil
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
        coordinate = locations.last?.coordinate
        if coordinate == nil {
            message = String(localized: "Location is unavailable. Choose a place from search.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        message = String(localized: "Location is unavailable. Choose a place from search.")
    }
}

#Preview {
    CardioAtlasPlacePicker(initialPlace: nil) { _ in true }
}
