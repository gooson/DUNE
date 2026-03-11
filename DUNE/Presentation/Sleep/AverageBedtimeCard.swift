import SwiftUI

struct AverageBedtimeCard: View {
    let averageBedtime: DateComponents

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Average Bedtime", systemImage: "moon.stars.fill")
                    .font(.callout)
                    .foregroundStyle(DS.Color.textSecondary)

                Text(formattedTime)
                    .font(valueFont)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(DS.Color.sleep)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, DS.Spacing.xxs)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Average Bedtime"))
            .accessibilityValue(Text(formattedTime))
        }
        .accessibilityIdentifier("sleep-average-bedtime-card")
    }

    private var formattedTime: String {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: Date())
        let hour = averageBedtime.hour ?? 0
        let minute = averageBedtime.minute ?? 0
        guard let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: anchor) else {
            return "--"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var valueFont: Font {
        sizeClass == .regular
            ? .system(.largeTitle, design: .rounded)
            : .system(.title, design: .rounded)
    }
}
