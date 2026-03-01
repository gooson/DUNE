import SwiftUI

/// Displays aggregate exercise totals (workouts, duration, calories, distance) for the selected period.
struct ExerciseTotalsView: View {
    let totals: ExerciseTotals
    let tintColor: Color

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }
    private var gridSpacing: CGFloat { isRegular ? DS.Spacing.lg : DS.Spacing.md }

    var body: some View {
        VStack(alignment: .leading, spacing: isRegular ? DS.Spacing.md : DS.Spacing.sm) {
            Text("Period Totals")
                .font(isRegular ? .headline : .subheadline)
                .fontWeight(.semibold)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 2),
                spacing: gridSpacing
            ) {
                totalItem(
                    icon: "number",
                    label: "Workouts",
                    value: totals.workoutCount.formattedWithSeparator
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
                        value: "\(Int(calories).formattedWithSeparator) kcal"
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

    private func totalItem(icon: String, label: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: isRegular ? DS.Spacing.md : DS.Spacing.sm) {
            Image(systemName: icon)
                .font(isRegular ? .subheadline : .caption)
                .foregroundStyle(tintColor)
                .frame(width: isRegular ? 24 : 20)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(label)
                    .font(isRegular ? .caption : .caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(isRegular ? .body : .subheadline)
                    .fontWeight(.medium)
            }

            Spacer(minLength: 0)
        }
        .padding(isRegular ? DS.Spacing.lg : DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: isRegular ? DS.Radius.md : DS.Radius.sm)
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
            return "\((meters / 1000.0).formattedWithSeparator(fractionDigits: 1)) km"
        }
        return "\(Int(meters).formattedWithSeparator) m"
    }
}
