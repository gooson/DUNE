import SwiftUI

/// Compact list of recent workouts with "See All" link.
struct ExerciseListSection: View {
    let workouts: [WorkoutSummary]
    let limit: Int

    init(workouts: [WorkoutSummary], limit: Int = 5) {
        self.workouts = workouts
        self.limit = limit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Section header
            HStack {
                Text("Recent Workouts")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if workouts.count > limit {
                    NavigationLink {
                        ExerciseView()
                    } label: {
                        Text("See All")
                            .font(.caption)
                            .foregroundStyle(DS.Color.activity)
                    }
                }
            }

            if workouts.isEmpty {
                InlineCard {
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundStyle(.secondary)
                        Text("No recent workouts")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            } else {
                ForEach(workouts.prefix(limit)) { workout in
                    InlineCard {
                        HStack(spacing: DS.Spacing.md) {
                            // Workout type icon
                            Image(systemName: workoutIcon(workout.type))
                                .foregroundStyle(DS.Color.activity)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(workout.type)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(workout.date, format: .dateTime.weekday(.wide).hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                                Text("\(Int(workout.duration / 60)) min")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let cal = workout.calories {
                                    Text("\(Int(cal)) kcal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func workoutIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "running":     "figure.run"
        case "walking":     "figure.walk"
        case "cycling":     "figure.outdoor.cycle"
        case "swimming":    "figure.pool.swim"
        case "hiking":      "figure.hiking"
        case "yoga":        "figure.yoga"
        default:            "figure.mixed.cardio"
        }
    }
}
