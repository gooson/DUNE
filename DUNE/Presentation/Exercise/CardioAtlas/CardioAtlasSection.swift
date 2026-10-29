import SwiftUI
import SwiftData

/// One extension point shared by local and HealthKit workout details.
struct CardioAtlasSection: View {
    let session: CardioAtlasSession
    let localRecordID: UUID?
    let healthKitWorkoutID: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
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
    @State private var saveError = false

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

    private var location: WorkoutLocationPayload {
        let saved = locationRecords.first?.payload
        return WorkoutLocationPayload(
            isIndoor: saved?.isIndoor ?? session.isIndoor,
            route: saved?.route.isEmpty == false ? (saved?.route ?? []) : healthKitRoute,
            place: saved?.place
        )
    }

    private var progress: CardioAtlasProgress? {
        CardioAtlasProgress.calculate(
            sessions: CardioAtlasHistory.sessions(records: records, workouts: workouts, current: session),
            currentSessionID: session.id,
            distanceGoalMeters: distanceGoal,
            durationGoalSeconds: durationGoal
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ViewThatFits(in: .horizontal) {
                HStack { heading; Spacer(); actions }
                VStack(alignment: .leading, spacing: DS.Spacing.sm) { heading; actions }
            }
            CardioAtlasMapView(location: location)
                .id(location)
            if isLoading {
                ProgressView("Loading recorded history")
                    .font(.caption)
            } else if routeUnavailable, location.route.isEmpty {
                Text("Recorded route could not be loaded.")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                Button("Try again") { Task { await loadHistory() } }
            }
            if let place = location.place {
                Label(place.name, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .accessibilityIdentifier("cardio-atlas-place-name")
            }
            if let progress {
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
        .accessibilityIdentifier("cardio-atlas-section")
        .task(id: healthKitWorkoutID) { await loadHistory() }
        .sheet(isPresented: $showPlacePicker) {
            CardioAtlasPlacePicker(initialPlace: location.place, onSave: savePlace)
        }
        .alert("Could not save place", isPresented: $saveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Label("Atlas", systemImage: "map")
                .font(.title3.weight(.semibold))
            if let indoor = location.isIndoor {
                Text(indoor ? String(localized: "Indoor") : String(localized: "Outdoor"))
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: DS.Spacing.md) {
            Button { showPlacePicker = true } label: {
                Label("Place", systemImage: "mappin.and.ellipse")
            }
            .accessibilityIdentifier("cardio-atlas-place")
            NavigationLink {
                CardioAtlasShareView(
                    session: session,
                    location: location,
                    journeySummary: progress.map { CardioAtlasFormatting.journey($0.journey) },
                    passportSummary: progress.map { CardioAtlasFormatting.passport(count: $0.achievements.count) }
                )
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("cardio-atlas-share")
        }
        .font(.subheadline)
        .buttonStyle(.bordered)
        .tint(theme.accentColor)
    }

    private func progressLinks(_ progress: CardioAtlasProgress) -> some View {
        VStack(spacing: DS.Spacing.md) {
            NavigationLink {
                CardioAtlasJourneyView(
                    progress: progress,
                    distanceGoal: $distanceGoal,
                    durationGoal: $durationGoal,
                    session: session,
                    sessions: CardioAtlasHistory.sessions(records: records, workouts: workouts, current: session)
                )
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
            NavigationLink {
                CardioAtlasPassportView(progress: progress, activityType: session.activityType)
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
        let result = await loadedWorkouts
        guard !Task.isCancelled else { return }
        workouts = result.workouts
        historyUnavailable = result.failed
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
    private func savePlace(_ place: WorkoutPlace?) {
        var updated = location
        updated.place = place
        let existing = locationRecords.first
        let previous = existing?.payload
        let record = existing ?? WorkoutLocationRecord(
            localRecordID: localRecordID, healthKitWorkoutID: healthKitWorkoutID, payload: updated
        )
        if existing == nil { modelContext.insert(record) }
        record.payload = updated
        do {
            try modelContext.save()
        } catch {
            if existing == nil { modelContext.delete(record) } else { record.payload = previous }
            saveError = true
        }
    }
}

/// View-layer adapter centralizes the same local/HealthKit identity rules as Activity.
@MainActor
enum CardioAtlasHistory {
    static func sessions(records: [ExerciseRecord], workouts: [WorkoutSummary], current: CardioAtlasSession) -> [CardioAtlasSession] {
        let local = records.compactMap { record -> CardioAtlasSession? in
            // An imported detail may be opened by HK identity even when a local alias exists.
            guard record.healthKitWorkoutID != current.id else { return nil }
            guard let type = WorkoutActivityType(rawValue: record.exerciseType)
                ?? WorkoutActivityType.infer(from: record.exerciseDefinitionID ?? "")
                ?? WorkoutActivityType.infer(from: record.exerciseType), type.isAtlasSupported else { return nil }
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
