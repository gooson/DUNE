import SwiftUI
import WatchKit

/// Pre-workout confirmation screen.
/// Strength: shows exercise list + Start button.
/// Cardio (single isDistanceBased exercise): shows Outdoor/Indoor choice.
struct WorkoutPreviewView: View {
    let snapshot: WorkoutSessionTemplate
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(WatchConnectivityManager.self) private var connectivity
    @Environment(\.dismiss) private var dismiss

    @State private var isStarting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if let cardioType = resolvedCardioType {
                cardioStartContent(activityType: cardioType)
            } else {
                strengthStartContent
            }
        }
        .background { WatchWaveBackground() }
        .navigationTitle(snapshot.name)
        .alert(String(localized: "Error"), isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Cardio Type Resolution

    /// Returns the WorkoutActivityType if this is a single-exercise cardio workout.
    /// Uses Domain-level `resolveDistanceBased` with inputType guard to avoid
    /// false positives such as `walking-lunge` being interpreted as walking cardio.
    private var resolvedCardioType: WorkoutActivityType? {
        guard snapshot.entries.count == 1 else { return nil }
        let entry = snapshot.entries[0]
        let inputType = resolvedInputType(for: entry.exerciseDefinitionID)
        return WorkoutActivityType.resolveDistanceBased(
            from: entry.exerciseDefinitionID,
            name: entry.exerciseName,
            inputTypeRaw: inputType
        )
    }

    /// Resolves watch-library input type for an exercise ID.
    /// Uses canonical ID matching so variant IDs share the same lookup behavior
    /// as the popularity/recent tracker.
    private func resolvedInputType(for exerciseID: String) -> String? {
        guard !exerciseID.isEmpty else { return nil }

        if let exact = connectivity.exerciseLibrary.first(where: { $0.id == exerciseID }) {
            return exact.inputType
        }

        let canonicalID = RecentExerciseTracker.canonicalExerciseID(exerciseID: exerciseID)
        return connectivity.exerciseLibrary.first {
            RecentExerciseTracker.canonicalExerciseID(exerciseID: $0.id) == canonicalID
        }?.inputType
    }

    // MARK: - Cardio Start

    private func cardioStartContent(activityType: WorkoutActivityType) -> some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                Image(systemName: activityType.iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(DS.Color.activity)
                    .padding(.top, DS.Spacing.lg)

                Text(LocalizedStringKey(activityType.typeName))
                    .font(DS.Typography.exerciseName)

                // Outdoor option
                Button {
                    startCardio(activityType: activityType, isOutdoor: true)
                } label: {
                    Label(String(localized: "Outdoor"), systemImage: "sun.max.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.positive)
                .disabled(isStarting)
                .accessibilityIdentifier("watch-workout-cardio-outdoor-button")

                // Indoor option
                Button {
                    startCardio(activityType: activityType, isOutdoor: false)
                } label: {
                    Label(String(localized: "Indoor"), systemImage: "building.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(isStarting)
                .accessibilityIdentifier("watch-workout-cardio-indoor-button")

                if isStarting {
                    ProgressView()
                        .padding(.top, DS.Spacing.sm)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func startCardio(activityType: WorkoutActivityType, isOutdoor: Bool) {
        guard !isStarting else { return }
        isStarting = true

        Task {
            do {
                try await workoutManager.requestAuthorization()
                try await workoutManager.startCardioSession(
                    activityType: activityType,
                    isOutdoor: isOutdoor
                )
                WKInterfaceDevice.current().play(.success)
                isStarting = false
            } catch {
                isStarting = false
                presentStartError(error)
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    // MARK: - Strength Start

    private var strengthStartContent: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(Array(snapshot.entries.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: DS.Spacing.md) {
                            Text("\(index + 1)")
                                .font(DS.Typography.metricLabel)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)

                            EquipmentIconView(equipment: entry.equipment, size: 20)
                                .frame(width: 20, height: 20)

                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(entry.exerciseName)
                                    .font(DS.Typography.tileSubtitle)
                                    .lineLimit(1)

                                HStack(spacing: DS.Spacing.xs) {
                                    Text("\(entry.defaultSets)\u{00d7}\(entry.defaultReps)")
                                    if let kg = entry.defaultWeightKg, kg > 0 {
                                        Text("\u{00b7} \(kg, specifier: "%.1f")kg")
                                    }
                                }
                                .font(DS.Typography.metricLabel)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(
                        String(
                            format: String(localized: "%@ exercises"),
                            locale: Locale.current,
                            snapshot.entries.count.formattedWithSeparator
                        )
                    )
                }
            }
            .scrollContentBackground(.hidden)

            Button {
                startStrengthWorkout()
            } label: {
                HStack {
                    if isStarting {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(String(localized: "Start"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.positive)
            .disabled(isStarting)
            .accessibilityIdentifier("watch-workout-start-button")
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xs)
        }
    }

    private func startStrengthWorkout() {
        guard !isStarting else { return }
        isStarting = true

        Task {
            do {
                try await workoutManager.requestAuthorization()
                try await workoutManager.startQuickWorkout(with: snapshot)
                WKInterfaceDevice.current().play(.success)
                isStarting = false
            } catch {
                isStarting = false
                presentStartError(error)
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    private func presentStartError(_ error: Error) {
        if let startupError = error as? WorkoutStartupError,
           let description = startupError.errorDescription,
           !description.isEmpty {
            errorMessage = description
            return
        }
        errorMessage = String(localized: "Could not start workout. Please try again.")
    }
}
