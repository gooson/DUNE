import SwiftData
import SwiftUI

struct WeeklyWorkoutPlanView: View {
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @AppStorage("workout.weeklyPlan.v1") private var planData = Data()
    @State private var selectedDate = Date()
    let onStartTemplate: (WorkoutTemplate) -> Void

    private var plan: WeeklyWorkoutPlan {
        (try? JSONDecoder().decode(WeeklyWorkoutPlan.self, from: planData)) ?? WeeklyWorkoutPlan()
    }

    private var days: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? calendar.startOfDay(for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        AdaptivePaneView {
            ScrollView {
                VStack(spacing: DS.Spacing.md) {
                    HStack {
                        Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Previous Week")
                        Spacer()
                        Text(selectedDate.formatted(.dateTime.year().month())).font(.headline)
                        Spacer()
                        Button { shiftWeek(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Next Week")
                    }
                    ForEach(days, id: \.self) { day in
                        Button { selectedDate = day } label: {
                            HStack {
                                Text(day.formatted(.dateTime.weekday().day()))
                                Spacer()
                                Text(templateName(on: day))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(DS.Spacing.md)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Calendar.current.isDate(day, inSameDayAs: selectedDate) ? DS.Color.activity.opacity(0.15) : .clear,
                                        in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(Calendar.current.isDate(day, inSameDayAs: selectedDate) ? .isSelected : [])
                        .dropDestination(for: String.self) { items, _ in
                            guard let text = items.first, let id = UUID(uuidString: text),
                                  templates.contains(where: { $0.id == id }) else { return false }
                            assign(id, to: day)
                            return true
                        }
                    }
                }
                .padding(DS.Spacing.lg)
            }
        } secondary: {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text(selectedDate.formatted(date: .complete, time: .omitted)).font(.headline)
                    if let id = plan.templateID(on: selectedDate) {
                        if let template = templates.first(where: { $0.id == id }) {
                            Button { onStartTemplate(template) } label: {
                                Label(template.name, systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("weekly-plan-selected-template")
                        } else {
                            Text("Template unavailable").foregroundStyle(.secondary)
                        }
                        Button("Remove from Plan", role: .destructive) { assign(nil, to: selectedDate) }
                            .accessibilityIdentifier("weekly-plan-remove")
                    }
                    Text("Plans are saved on this device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Choose a template or drag it onto a day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(templates) { template in
                        Button { assign(template.id, to: selectedDate) } label: {
                            Label(template.name, systemImage: "plus.circle")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .draggable(template.id.uuidString)
                        .accessibilityIdentifier("weekly-plan-template-\(template.id.uuidString)")
                    }
                    if templates.isEmpty {
                        ContentUnavailableView("No Templates", systemImage: "list.clipboard")
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("weekly-plan-template-list")
        }
        .navigationTitle("Weekly Workout Plan")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weekly-workout-plan")
    }

    private func templateName(on date: Date) -> String {
        guard let id = plan.templateID(on: date) else { return String(localized: "Rest Day") }
        return templates.first(where: { $0.id == id })?.name ?? String(localized: "Template unavailable")
    }

    private func assign(_ id: UUID?, to date: Date) {
        var updated = plan
        updated.assign(id, to: date)
        if let data = try? JSONEncoder().encode(updated) { planData = data }
    }

    private func shiftWeek(_ offset: Int) {
        if let date = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: selectedDate) { selectedDate = date }
    }
}
