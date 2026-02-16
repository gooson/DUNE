import SwiftUI
import SwiftData
import Charts

struct BodyCompositionView: View {
    @State private var viewModel = BodyCompositionViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyCompositionRecord.date, order: .reverse) private var records: [BodyCompositionRecord]

    private var allItems: [BodyCompositionListItem] {
        viewModel.allItems(manualRecords: records)
    }

    var body: some View {
        Group {
            if records.isEmpty && viewModel.healthKitItems.isEmpty && !viewModel.isLoadingHealthKit {
                EmptyStateView(
                    icon: "figure.stand",
                    title: "No Body Records",
                    message: "Track your weight, body fat, and muscle mass to monitor changes over time.",
                    actionTitle: "Add First Record",
                    action: {
                        viewModel.resetForm()
                        viewModel.isShowingAddSheet = true
                    }
                )
            } else if viewModel.isLoadingHealthKit && records.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        let items = allItems
                        let weightItems = items.filter { $0.weight != nil }
                        if weightItems.count >= 2 {
                            weightTrendChart(weightItems)
                        }
                        if let latest = items.first {
                            latestValuesCard(latest)
                        }
                        historySection(items)
                    }
                    .padding()
                }
            }
        }
        .task {
            await viewModel.loadHealthKitData()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.resetForm()
                    viewModel.isShowingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("body-add-button")
            }
        }
        .sheet(isPresented: $viewModel.isShowingAddSheet) {
            BodyCompositionFormSheet(
                viewModel: viewModel,
                isEdit: false,
                onSave: {
                    if let record = viewModel.createValidatedRecord() {
                        modelContext.insert(record)
                        viewModel.resetForm()
                        viewModel.isShowingAddSheet = false
                    }
                }
            )
        }
        .sheet(isPresented: $viewModel.isShowingEditSheet) {
            if let record = viewModel.editingRecord {
                BodyCompositionFormSheet(
                    viewModel: viewModel,
                    isEdit: true,
                    onSave: {
                        if viewModel.applyUpdate(to: record) {
                            viewModel.isShowingEditSheet = false
                            viewModel.editingRecord = nil
                        }
                    }
                )
            }
        }
        .navigationTitle("Body")
    }

    // MARK: - Components

    private func weightTrendChart(_ weightItems: [BodyCompositionListItem]) -> some View {
        let sorted = weightItems.sorted { $0.date < $1.date }

        return StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Weight Trend")
                    .font(.headline)

                Chart(sorted, id: \.id) { item in
                    if let weight = item.weight {
                        LineMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Weight", weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(DS.Color.body)

                        PointMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Weight", weight)
                        )
                        .foregroundStyle(DS.Color.body)
                        .symbolSize(30)
                    }
                }
                .frame(height: 180)
            }
        }
    }

    private func latestValuesCard(_ item: BodyCompositionListItem) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: 16) {
                if let weight = item.weight {
                    metricBadge(label: "Weight", value: String(format: "%.1f", weight), unit: "kg")
                }
                if let fat = item.bodyFatPercentage {
                    metricBadge(label: "Body Fat", value: String(format: "%.1f", fat), unit: "%")
                }
                if let muscle = item.muscleMass {
                    metricBadge(label: "Muscle", value: String(format: "%.1f", muscle), unit: "kg")
                }
            }
            .frame(maxWidth: .infinity)

            if item.source == .healthKit {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(item.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func metricBadge(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func historySection(_ items: [BodyCompositionListItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History")
                .font(.headline)

            ForEach(items) { item in
                historyRow(item)
            }
        }
    }

    private func historyRow(_ item: BodyCompositionListItem) -> some View {
        HStack {
            if item.source == .healthKit {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(item.date, style: .date)
                    .font(.subheadline)
                HStack(spacing: DS.Spacing.md) {
                    if let w = item.weight { Text("\(String(format: "%.1f", w))kg").font(.caption).foregroundStyle(.secondary) }
                    if let f = item.bodyFatPercentage { Text("\(String(format: "%.1f", f))%").font(.caption).foregroundStyle(.secondary) }
                    if let m = item.muscleMass { Text("\(String(format: "%.1f", m))kg").font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            if item.source == .manual {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        .contextMenu {
            if item.source == .manual, let record = findManualRecord(id: item.id) {
                Button {
                    viewModel.startEditing(record)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    modelContext.delete(record)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func findManualRecord(id: String) -> BodyCompositionRecord? {
        records.first { $0.id.uuidString == id }
    }
}

// MARK: - Form Sheet

private struct BodyCompositionFormSheet: View {
    @Bindable var viewModel: BodyCompositionViewModel
    let isEdit: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var saveCount = 0

    var body: some View {
        NavigationStack {
            Form {
                if let error = viewModel.validationError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                DatePicker(
                    "Date & Time",
                    selection: $viewModel.selectedDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .accessibilityIdentifier("body-date-picker")

                TextField("Weight (kg)", text: $viewModel.newWeight)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("body-weight-field")
                TextField("Body Fat (%)", text: $viewModel.newBodyFat)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("body-fat-field")
                TextField("Muscle Mass (kg)", text: $viewModel.newMuscleMass)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("body-muscle-field")
                TextField("Memo", text: $viewModel.newMemo)
            }
            .navigationTitle(isEdit ? "Edit Record" : "Add Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("body-cancel-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCount += 1
                        onSave()
                    }
                    .disabled(viewModel.newWeight.isEmpty && viewModel.newBodyFat.isEmpty && viewModel.newMuscleMass.isEmpty)
                    .accessibilityIdentifier("body-save-button")
                }
            }
        }
        .sensoryFeedback(.success, trigger: saveCount)
    }
}

#Preview {
    BodyCompositionView()
        .modelContainer(for: BodyCompositionRecord.self, inMemory: true)
}
