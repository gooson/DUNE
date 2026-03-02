import SwiftUI
import WatchKit

/// Pre-workout confirmation screen.
/// Strength: shows exercise list + Start button.
/// Cardio (single isDistanceBased exercise): shows Outdoor/Indoor choice.
struct WorkoutPreviewView: View {
    let snapshot: WorkoutSessionTemplate
    @Environment(WorkoutManager.self) private var workoutManager
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
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Cardio Type Resolution

    /// Returns the WorkoutActivityType if this is a single-exercise cardio workout.
    private var resolvedCardioType: WorkoutActivityType? {
        guard snapshot.entries.count == 1 else { return nil }
        let entry = snapshot.entries[0]
        // Try direct rawValue match first
        if let type = WorkoutActivityType(rawValue: entry.exerciseDefinitionID),
           type.isDistanceBased {
            return type
        }
        // Try stem extraction for variants like "running-treadmill"
        let stem = entry.exerciseDefinitionID.components(separatedBy: "-").first ?? ""
        if let type = WorkoutActivityType(rawValue: stem),
           type.isDistanceBased {
            return type
        }
        // Try name-based inference
        if let type = WorkoutActivityType.infer(from: entry.exerciseName),
           type.isDistanceBased {
            return type
        }
        return nil
    }

    // MARK: - Cardio Start

    private func cardioStartContent(activityType: WorkoutActivityType) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            Image(systemName: cardioIconName(for: activityType))
                .font(.system(size: 40))
                .foregroundStyle(DS.Color.activity)

            Text(activityType.typeName)
                .font(DS.Typography.exerciseName)

            Spacer()

            // Outdoor option
            Button {
                startCardio(activityType: activityType, isOutdoor: true)
            } label: {
                Label("Outdoor", systemImage: "sun.max.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.positive)
            .disabled(isStarting)

            // Indoor option
            Button {
                startCardio(activityType: activityType, isOutdoor: false)
            } label: {
                Label("Indoor", systemImage: "building.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(isStarting)

            if isStarting {
                ProgressView()
                    .padding(.top, DS.Spacing.sm)
            }

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
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
                errorMessage = "Failed to start: \(error.localizedDescription)"
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
                                        Text("· \(kg, specifier: "%.1f")kg")
                                    }
                                }
                                .font(DS.Typography.metricLabel)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("\(snapshot.entries.count) exercises")
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
                    Text("Start")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.positive)
            .disabled(isStarting)
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
                errorMessage = "Failed to start: \(error.localizedDescription)"
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    // MARK: - Icon Helper

    private func cardioIconName(for activityType: WorkoutActivityType) -> String {
        switch activityType {
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .hiking: "figure.hiking"
        case .elliptical: "figure.elliptical"
        case .rowing: "figure.rower"
        case .handCycling: "figure.hand.cycling"
        case .crossCountrySkiing: "figure.skiing.crosscountry"
        case .downhillSkiing: "figure.skiing.downhill"
        case .paddleSports: "oar.2.crossed"
        case .swimBikeRun: "figure.run"
        default: "figure.run"
        }
    }
}
