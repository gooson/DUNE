import SwiftUI
import SwiftData

/// One extension point shared by local and HealthKit workout details.
struct CardioAtlasSection: View {
    private enum Destination: Identifiable {
        case share
        case journey(CardioAtlasProgress)
        case passport(CardioAtlasProgress)

        var id: String {
            switch self {
            case .share: "share"
            case .journey: "journey"
            case .passport: "passport"
            }
        }
    }

    let session: CardioAtlasSession
    let localRecordID: UUID?
    let healthKitWorkoutID: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \ExerciseRecord.date) private var records: [ExerciseRecord]
    @Query private var locationRecords: [WorkoutLocationRecord]
    @AppStorage("cardioAtlas.journey.distanceGoalMeters") private var distanceGoal = 20_000.0
    @AppStorage("cardioAtlas.journey.durationGoalSeconds") private var durationGoal = 10_800.0
    @State private var workouts: [WorkoutSummary] = []
    @State private var healthKitRoute: [WorkoutRoutePoint] = []
    @State private var isLoading = true
    @State private var routeUnavailable = false
    @State private var historyUnavailable = false
    @State private var showPlacePicker = false
    @State private var destination: Destination?
    @State private var displayLocation = WorkoutLocationPayload()
    @State private var preparedProgress: CardioAtlasProgress?
    @State private var mapRevision = UUID()
    @State private var isPreparingLocation = true
    @State private var isLoadingRoute = false

    init(session: CardioAtlasSession, localRecordID: UUID? = nil, healthKitWorkoutID: String? = nil) {
        self.session = session
        self.localRecordID = localRecordID
        self.healthKitWorkoutID = healthKitWorkoutID
        // Nonmatching sentinels avoid a nil-ID predicate accidentally fetching every record.
        let localID = localRecordID ?? UUID()
        let healthID = healthKitWorkoutID ?? ""
        _locationRecords = Query(
            filter: #Predicate<WorkoutLocationRecord> {
                $0.localRecordID == localID || $0.healthKitWorkoutID == healthID
            },
            sort: \WorkoutLocationRecord.updatedAt,
            order: .reverse
        )
    }

    private func prepareLocation() {
        let saved = locationRecords.first?.payload
        let next = WorkoutLocationPayload(
            isIndoor: saved?.isIndoor ?? session.isIndoor,
            route: saved?.route.isEmpty == false ? (saved?.route ?? []) : healthKitRoute,
            place: saved?.place
        )
        if next != displayLocation {
            displayLocation = next
            mapRevision = UUID()
        }
        isPreparingLocation = false
    }

    private func prepareProgress() {
        preparedProgress = CardioAtlasProgress.calculate(
            sessions: CardioAtlasHistory.sessions(records: records, workouts: workouts, current: session),
            currentSessionID: session.id,
            distanceGoalMeters: distanceGoal,
            durationGoalSeconds: durationGoal
        )
    }

    private func prepareProgressGoal() {
        preparedProgress = preparedProgress?.updatingJourneyGoal(
            distanceMeters: distanceGoal, durationSeconds: durationGoal
        )
    }

    // Cheap scalar projections observe edits as well as insertion/deletion without repeatedly
    // sorting history or decoding thousands of coordinates during unrelated body updates.
    private var historyInputs: [CardioAtlasRecordRevision] {
        records.map { record in
            CardioAtlasRecordRevision(
                id: record.id, date: record.date.timeIntervalSinceReferenceDate.isFinite ? record.date : .distantPast,
                type: record.exerciseType, definitionID: record.exerciseDefinitionID,
                duration: record.duration.isFinite ? record.duration : 0,
                distance: record.distance.flatMap { $0.isFinite ? $0 : nil }, healthKitID: record.healthKitWorkoutID
            )
        }
    }

    private var locationInputs: [CardioAtlasLocationRevision] {
        locationRecords.map { CardioAtlasLocationRevision(id: $0.id, updatedAt: $0.updatedAt) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) { heading; actions }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack { heading; Spacer(); actions }
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) { heading; actions }
                }
            }
            mapContent
            if isLoading {
                ProgressView("Loading recorded history")
                    .font(.caption)
            } else if routeUnavailable, displayLocation.route.isEmpty {
                Button("Try again") { Task { await loadHistory() } }
            }
            if let place = displayLocation.place {
                Label(place.name, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .accessibilityIdentifier("cardio-atlas-place-name")
            }
            if let progress = preparedProgress, !isLoading {
                progressLinks(progress)
            }
            Text(historyUnavailable
                 ? String(localized: "Progress uses available workout records.")
                 : String(localized: "Progress from available history through this workout."))
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .padding(DS.Spacing.lg)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cardio-atlas-section")
        .onChange(of: historyInputs, initial: true) { prepareProgress() }
        .onChange(of: locationInputs, initial: true) { prepareLocation() }
        .onChange(of: distanceGoal) { prepareProgressGoal() }
        .onChange(of: durationGoal) { prepareProgressGoal() }
        .task(id: healthKitWorkoutID) { await loadHistory() }
        .sheet(isPresented: $showPlacePicker) {
            CardioAtlasPlacePicker(initialPlace: displayLocation.place, onSave: savePlace)
        }
        .sheet(item: $destination) { destination in
            // An inspector can route NavigationLinks into its presenting tab's stack.
            // Keep Atlas destinations in their own visible modal navigation context.
            NavigationStack {
                destinationContent(destination)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { self.destination = nil }
                                .accessibilityIdentifier("cardio-atlas-destination-close")
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func destinationContent(_ destination: Destination) -> some View {
        switch destination {
        case .share:
            CardioAtlasShareView(
                session: session,
                location: displayLocation,
                journeySummary: isLoading ? nil : preparedProgress.map { CardioAtlasFormatting.journey($0.journey) },
                passportSummary: isLoading ? nil : preparedProgress.map { CardioAtlasFormatting.passport(count: $0.achievements.count) }
            )
        case .journey(let progress):
            CardioAtlasJourneyView(
                progress: progress,
                distanceGoal: $distanceGoal,
                durationGoal: $durationGoal,
                activityType: session.activityType
            )
        case .passport(let progress):
            CardioAtlasPassportView(progress: progress, activityType: session.activityType)
        }
    }

    @ViewBuilder
    private var mapContent: some View {
        if displayLocation.route.isEmpty && displayLocation.place == nil && (isPreparingLocation || isLoadingRoute) {
            ProgressView("Loading recorded route")
                .frame(maxWidth: .infinity).frame(height: 240)
                .accessibilityIdentifier("cardio-atlas-map-loading")
        } else if displayLocation.route.isEmpty && displayLocation.place == nil && routeUnavailable {
            ContentUnavailableView("Recorded route could not be loaded.", systemImage: "map",
                                   description: Text("Workout metrics are still available."))
                .frame(height: 240)
                .accessibilityIdentifier("cardio-atlas-map-error")
        } else {
            CardioAtlasMapView(location: displayLocation).id(mapRevision)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Label("Atlas", systemImage: "map")
                .font(.title3.weight(.semibold))
            if let indoor = displayLocation.isIndoor {
                Text(indoor ? String(localized: "Indoor") : String(localized: "Outdoor"))
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    private var actions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
        return layout {
            Button { showPlacePicker = true } label: {
                Label("Place", systemImage: "mappin.and.ellipse")
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            }
            .accessibilityIdentifier("cardio-atlas-place")
            Button {
                destination = .share
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            }
            .accessibilityIdentifier("cardio-atlas-share")
        }
        .font(.subheadline)
        .buttonStyle(.bordered)
        .tint(theme.accentColor)
    }

    private func progressLinks(_ progress: CardioAtlasProgress) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Button {
                destination = .journey(progress)
            } label: {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack {
                        Label("Journey", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        Spacer()
                        Text(CardioAtlasFormatting.journey(progress.journey))
                            .monospacedDigit()
                    }
                    ProgressView(value: progress.journey.fraction)
                        .tint(theme.accentColor)
                }
            }
            .accessibilityIdentifier("cardio-atlas-journey")
            Divider()
            Button {
                destination = .passport(progress)
            } label: {
                HStack {
                    Label("Passport", systemImage: "medal")
                    Spacer()
                    Text(CardioAtlasFormatting.passport(count: progress.achievements.count))
                        .monospacedDigit()
                    Image(systemName: "chevron.right").font(.caption)
                }
            }
            .accessibilityIdentifier("cardio-atlas-passport")
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
    }

    @MainActor
    private func loadHistory() async {
        isLoading = true
        routeUnavailable = false
        historyUnavailable = false
        isLoadingRoute = healthKitWorkoutID != nil && locationRecords.first?.payload?.route.isEmpty != false
        // Existing Activity history uses the same ten-year authorized window.
        async let loadedWorkouts = loadWorkouts()
        if let healthKitWorkoutID, locationRecords.first?.payload?.route.isEmpty != false {
            do {
                let route = try await WorkoutRouteQueryService().fetchRoute(workoutID: healthKitWorkoutID)
                guard !Task.isCancelled else { return }
                healthKitRoute = route
            } catch {
                guard !Task.isCancelled else { return }
                routeUnavailable = true
            }
        }
        isLoadingRoute = false
        prepareLocation()
        let result = await loadedWorkouts
        guard !Task.isCancelled else { return }
        workouts = result.workouts
        historyUnavailable = result.failed
        prepareProgress()
        isLoading = false
    }

    private func loadWorkouts() async -> (workouts: [WorkoutSummary], failed: Bool) {
        do {
            return (try await WorkoutQueryService(manager: .shared).fetchWorkouts(days: 3_650), false)
        } catch {
            return ([], true)
        }
    }

    @MainActor
    private func savePlace(_ place: WorkoutPlace?) -> Bool {
        var updated = displayLocation
        updated.place = place
        let existing = locationRecords.first
        let previousData = existing?.payloadData
        let previousUpdatedAt = existing?.updatedAt
        let record = existing ?? WorkoutLocationRecord(
            localRecordID: localRecordID, healthKitWorkoutID: healthKitWorkoutID, payload: updated
        )
        if existing == nil { modelContext.insert(record) }
        record.payload = updated
        do {
            try modelContext.save()
            prepareLocation()
            return true
        } catch {
            if existing == nil {
                modelContext.delete(record)
            } else {
                record.payloadData = previousData
                if let previousUpdatedAt { record.updatedAt = previousUpdatedAt }
            }
            AppLogger.ui.error("Could not save workout place: \(error.localizedDescription)")
            return false
        }
    }
}

private struct CardioAtlasRecordRevision: Equatable {
    let id: UUID
    let date: Date
    let type: String
    let definitionID: String?
    let duration: TimeInterval
    let distance: Double?
    let healthKitID: String?
}

private struct CardioAtlasLocationRevision: Equatable {
    let id: UUID
    let updatedAt: Date
}

/// View-layer adapter centralizes the same local/HealthKit identity rules as Activity.
@MainActor
enum CardioAtlasHistory {
    static func sessions(records: [ExerciseRecord], workouts: [WorkoutSummary], current: CardioAtlasSession) -> [CardioAtlasSession] {
        let local = records.compactMap { record -> CardioAtlasSession? in
            // An imported detail may be opened by HK identity even when a local alias exists.
            guard record.healthKitWorkoutID != current.id else { return nil }
            let resolvedType = WorkoutActivityType(rawValue: record.exerciseType)
                ?? record.exerciseDefinitionID.flatMap { WorkoutActivityType(rawValue: $0) }
                ?? WorkoutActivityType.infer(from: record.exerciseDefinitionID ?? "")
                ?? WorkoutActivityType.infer(from: record.exerciseType)
            guard let type = resolvedType, type.isAtlasSupported else { return nil }
            return CardioAtlasSession(
                id: record.id.uuidString, activityType: type, date: record.date,
                duration: record.duration, distanceMeters: record.distance.map { $0 * 1_000 }
            )
        }
        let remote = workouts.filteringAppDuplicates(
            against: records, tombstonedIDs: DeletedWorkoutTombstoneStore.shared.tombstonedIDs
        ).filter { $0.activityType.isAtlasSupported }.map { workout in
            CardioAtlasSession(
                id: workout.id, activityType: workout.activityType, date: workout.date,
                duration: workout.duration, distanceMeters: workout.distance, isIndoor: workout.isIndoor
            )
        }
        // Details can be opened before the history request returns or outside its window.
        return (local + remote).filter { $0.id != current.id } + [current]
    }
}

extension WorkoutActivityType {
    var isAtlasSupported: Bool {
        switch category {
        case .cardio, .dance, .water, .winter, .combat, .sports, .outdoor, .multiSport: true
        default: false
        }
    }
}
