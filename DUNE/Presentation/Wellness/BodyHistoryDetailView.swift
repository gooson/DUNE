import SwiftUI
import SwiftData

struct BodyHistoryDetailView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    private static let lightBodyIconColor = DS.Color.body.mix(with: .black, by: 0.35)
    @Bindable var viewModel: BodyCompositionViewModel
    let onRecordsChanged: @MainActor () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyCompositionRecord.date, order: .reverse) private var records: [BodyCompositionRecord]

    @State private var recordToDelete: BodyCompositionRecord?
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingEditSheet = false

    private var allItems: [BodyCompositionListItem] {
        viewModel.allItems(manualRecords: records)
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("body-history-detail-screen")

            Group {
                if allItems.isEmpty {
                    EmptyStateView(
                        icon: "figure.stand",
                        title: "No Records",
                        message: "Your body composition records will appear here."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.sm) {
                            ForEach(Array(allItems.enumerated()), id: \.element.id) { index, item in
                                historyRow(item, rowIndex: index)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .background { DetailWaveBackground() }
        .task {
            await viewModel.loadHealthKitData()
        }
        .englishNavigationTitle("Body Records")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Record?", isPresented: $isShowingDeleteConfirmation, presenting: recordToDelete) { record in
            Button("Delete", role: .destructive) {
                let writeInput = BodyCompositionWriteInput(record: record)
                Task {
                    do {
                        try await BodyCompositionWriteService().delete(
                            recordID: record.id,
                            input: writeInput
                        )
                        await viewModel.loadHealthKitData()
                        await MainActor.run {
                            withAnimation {
                                modelContext.delete(record)
                            }
                            recordToDelete = nil
                            onRecordsChanged()
                        }
                    } catch {
                        AppLogger.healthKit.error("Deleting body record failed: \(error.localizedDescription)")
                        await MainActor.run {
                            recordToDelete = nil
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                recordToDelete = nil
            }
        } message: { record in
            Text("This record from \(record.date.formatted(date: .abbreviated, time: .omitted)) will be permanently deleted from all your devices.")
        }
        .sheet(isPresented: $isShowingEditSheet, onDismiss: {
            viewModel.editingRecord = nil
        }) {
            if let record = viewModel.editingRecord {
                BodyCompositionFormSheet(
                    viewModel: viewModel,
                    isEdit: true,
                    onSave: {
                        let previousInput = BodyCompositionWriteInput(record: record)
                        guard let draft = viewModel.createValidatedDraft() else {
                            return false
                        }
                        do {
                            try await BodyCompositionWriteService().update(
                                recordID: record.id,
                                previousInput: previousInput,
                                input: draft.writeInput
                            )
                            try modelContext.transaction {
                                viewModel.apply(draft, to: record)
                            }
                            viewModel.didFinishSaving()
                            await viewModel.loadHealthKitData()
                            isShowingEditSheet = false
                            onRecordsChanged()
                            return true
                        } catch {
                            viewModel.validationError = String(localized: "Failed to save record changes. Please try again.")
                            viewModel.didFinishSaving()
                        }
                        return false
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func metricValues(for item: BodyCompositionListItem) -> some View {
        if let weight = item.weight {
            metricValue(Text("\(weight.formattedWithSeparator(fractionDigits: 1)) kg"), category: .weight)
        }
        if let fat = item.bodyFatPercentage {
            metricValue(Text("\(fat.formattedWithSeparator(fractionDigits: 1))%"), category: .bodyFat)
        }
        if let muscle = item.muscleMass {
            metricValue(
                Text("\(muscle.formattedWithSeparator(fractionDigits: 1)) kg"),
                category: .leanBodyMass,
                accessibilityLabel: item.source == .manual
                    ? Text("Muscle Mass (kg)")
                        + Text(verbatim: ": ")
                        + Text(verbatim: muscle.formattedWithSeparator(fractionDigits: 1))
                    : nil
            )
        }
    }

    private func metricValue(
        _ value: Text,
        category: HealthMetric.Category,
        accessibilityLabel: Text? = nil
    ) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: category.iconName)
                .foregroundStyle(colorScheme == .light ? Self.lightBodyIconColor : category.themeColor)
                .accessibilityHidden(true)
            value
                .foregroundStyle(.primary)
        }
        .font(.caption)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(category.themeColor.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? (Text(category.displayName) + Text(verbatim: ": ") + value))
        .fixedSize(horizontal: true, vertical: false)
    }

    private func historyRow(_ item: BodyCompositionListItem, rowIndex: Int) -> some View {
        HStack {
            if item.source == .healthKit {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(item.date, style: .date)
                    .font(.subheadline.weight(.semibold))
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        metricValues(for: item)
                    }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: DS.Spacing.xs) {
                            metricValues(for: item)
                        }
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            metricValues(for: item)
                        }
                    }
                }
            }
            Spacer()
            if item.source == .manual {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .padding(DS.Spacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        .accessibilityIdentifier(rowIdentifier(for: item, rowIndex: rowIndex))
        .contextMenu {
            if item.source == .manual, let record = findManualRecord(id: item.id) {
                Button {
                    viewModel.startEditing(record, presentsSheet: false)
                    isShowingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .accessibilityIdentifier("body-history-edit-action")
                Button(role: .destructive) {
                    recordToDelete = record
                    isShowingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func findManualRecord(id: String) -> BodyCompositionRecord? {
        records.first { $0.id.uuidString == id }
    }

    private func rowIdentifier(for item: BodyCompositionListItem, rowIndex: Int) -> String {
        if item.source == .manual {
            let manualIndex = allItems[..<rowIndex].filter { $0.source == .manual }.count
            return "body-history-row-manual-\(manualIndex)"
        }
        return "body-history-row-healthkit-\(rowIndex)"
    }
}
