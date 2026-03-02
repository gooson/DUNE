import SwiftUI
import CoreLocation

/// Indoor/Outdoor selection sheet shown before starting a cardio session.
struct CardioStartSheet: View {
    let exercise: ExerciseDefinition
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOutdoor: Bool?
    @State private var locationAuthStatus: CLAuthorizationStatus = CLLocationManager().authorizationStatus

    private var activityType: WorkoutActivityType {
        WorkoutActivityType.resolveDistanceBased(from: exercise.id, name: exercise.name)
            ?? exercise.resolvedActivityType
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                Spacer()

                activityHeader

                modeButtons

                if locationAuthStatus == .denied || locationAuthStatus == .restricted {
                    locationWarning
                } else if locationAuthStatus == .notDetermined {
                    locationNotice
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .background { SheetWaveBackground() }
            .navigationTitle(exercise.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedOutdoor) { isOutdoor in
                CardioSessionView(
                    exercise: exercise,
                    activityType: activityType,
                    isOutdoor: isOutdoor,
                    onComplete: { dismiss() }
                )
            }
        }
    }

    // MARK: - Activity Header

    private var activityHeader: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: activityType.iconName)
                .font(.system(size: 48))
                .foregroundStyle(DS.Color.activity)

            Text(exercise.localizedName)
                .font(.title2.weight(.bold))
        }
    }

    // MARK: - Mode Buttons

    private var modeButtons: some View {
        VStack(spacing: DS.Spacing.md) {
            modeButton(
                title: String(localized: "Outdoor"),
                subtitle: String(localized: "GPS distance tracking"),
                icon: "sun.max.fill",
                isOutdoor: true
            )

            modeButton(
                title: String(localized: "Indoor"),
                subtitle: String(localized: "Timer and calories only"),
                icon: "house.fill",
                isOutdoor: false
            )
        }
    }

    private func modeButton(title: String, subtitle: String, icon: String, isOutdoor: Bool) -> some View {
        Button {
            selectedOutdoor = isOutdoor
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isOutdoor ? DS.Color.positive : DS.Color.activity)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(DS.Color.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Location Warning

    private var locationWarning: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "location.slash")
                .foregroundStyle(DS.Color.caution)
            Text("Location access denied. Enable in Settings for outdoor distance tracking.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.caution.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Location Notice (not yet determined)

    private var locationNotice: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "location")
                .foregroundStyle(DS.Color.activity)
            Text("Outdoor mode will request location permission.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.activity.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}
