import SwiftUI

/// Displays aggregate exercise totals (workouts, duration, calories, distance) for the selected period.
struct ExerciseTotalsView: View {
    let totals: ExerciseTotals
    let tintColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Period Totals")
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.md), count: 2),
                spacing: DS.Spacing.md
            ) {
                totalItem(
                    icon: "number",
                    label: "Workouts",
                    value: "\(totals.workoutCount)"
                )

                totalItem(
                    icon: "clock",
                    label: "Duration",
                    value: formatDuration(totals.totalDuration)
                )

                if let calories = totals.totalCalories {
                    totalItem(
                        icon: "flame",
                        label: "Calories",
                        value: "\(Int(calories)) kcal"
                    )
                }

                if let meters = totals.totalDistanceMeters {
                    totalItem(
                        icon: "point.bottomleft.forward.to.point.topright.scurvepath",
                        label: "Distance",
                        value: formatDistance(meters)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Subviews

    private func totalItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tintColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.thinMaterial)
        }
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000.0)
        }
        return "\(Int(meters)) m"
    }
}
