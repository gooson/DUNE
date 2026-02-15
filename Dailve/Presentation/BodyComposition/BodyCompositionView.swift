import SwiftUI
import SwiftData
import Charts

struct BodyCompositionView: View {
    @State private var viewModel = BodyCompositionViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyCompositionRecord.date, order: .reverse) private var records: [BodyCompositionRecord]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Weight Trend Chart
                    if records.count >= 2 {
                        weightTrendChart
                    }

                    // Latest Values
                    if let latest = records.first {
                        latestValuesCard(latest)
                    }

                    // History List
                    historySection
                }
                .padding()
            }
            .navigationTitle("Body")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.resetForm()
                        viewModel.isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
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
        }
    }

    // MARK: - Components

    private var weightTrendChart: some View {
        let weightRecords = records.filter { $0.weight != nil }.reversed()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Weight Trend")
                .font(.headline)

            Chart(Array(weightRecords), id: \.id) { record in
                if let weight = record.weight {
                    LineMark(
                        x: .value("Date", record.date, unit: .day),
                        y: .value("Weight", weight)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)

                    PointMark(
                        x: .value("Date", record.date, unit: .day),
                        y: .value("Weight", weight)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(30)
                }
            }
            .frame(height: 180)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func latestValuesCard(_ record: BodyCompositionRecord) -> some View {
        HStack(spacing: 16) {
            if let weight = record.weight {
                metricBadge(label: "Weight", value: String(format: "%.1f", weight), unit: "kg")
            }
            if let fat = record.bodyFatPercentage {
                metricBadge(label: "Body Fat", value: String(format: "%.1f", fat), unit: "%")
            }
            if let muscle = record.muscleMass {
                metricBadge(label: "Muscle", value: String(format: "%.1f", muscle), unit: "kg")
            }
        }
        .frame(maxWidth: .infinity)
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

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History")
                .font(.headline)

            ForEach(records) { record in
                historyRow(record)
            }
        }
    }

    private func historyRow(_ record: BodyCompositionRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.date, style: .date)
                    .font(.subheadline)
                HStack(spacing: 12) {
                    if let w = record.weight { Text("\(String(format: "%.1f", w))kg").font(.caption).foregroundStyle(.secondary) }
                    if let f = record.bodyFatPercentage { Text("\(String(format: "%.1f", f))%").font(.caption).foregroundStyle(.secondary) }
                    if let m = record.muscleMass { Text("\(String(format: "%.1f", m))kg").font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            Button {
                viewModel.startEditing(record)
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(record)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Form Sheet

private struct BodyCompositionFormSheet: View {
    @Bindable var viewModel: BodyCompositionViewModel
    let isEdit: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Weight (kg)", text: $viewModel.newWeight)
                    .keyboardType(.decimalPad)
                TextField("Body Fat (%)", text: $viewModel.newBodyFat)
                    .keyboardType(.decimalPad)
                TextField("Muscle Mass (kg)", text: $viewModel.newMuscleMass)
                    .keyboardType(.decimalPad)
                TextField("Memo", text: $viewModel.newMemo)
            }
            .navigationTitle(isEdit ? "Edit Record" : "Add Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .disabled(viewModel.newWeight.isEmpty && viewModel.newBodyFat.isEmpty && viewModel.newMuscleMass.isEmpty)
                }
            }
        }
    }
}

#Preview {
    BodyCompositionView()
        .modelContainer(for: BodyCompositionRecord.self, inMemory: true)
}
