import SwiftUI
import SwiftData

/// Full injury history — active injuries at top, ended injuries below.
struct InjuryHistoryView: View {
    @Bindable var viewModel: InjuryViewModel
    @Query(sort: \InjuryRecord.startDate, order: .reverse) private var allRecords: [InjuryRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .title3) private var rowIconWidth: CGFloat = 28
    @State private var recordToDelete: InjuryRecord?
    @State private var cachedActiveRecords: [InjuryRecord] = []
    @State private var cachedEndedRecords: [InjuryRecord] = []

    @State private var showingStatistics = false
    @State private var selectedInjury: InjuryDetailDestination?

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("injury-history-screen")

            List {
                if !cachedActiveRecords.isEmpty {
                    Section {
                        ForEach(cachedActiveRecords) { record in
                            injuryRow(record)
                        }
                    } header: {
                        Label("Active", systemImage: "bandage.fill")
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }

                if !cachedEndedRecords.isEmpty {
                    Section {
                        ForEach(cachedEndedRecords) { record in
                            injuryRow(record)
                        }
                    } header: {
                        Label("Recovered", systemImage: "checkmark.circle")
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }

                if allRecords.isEmpty {
                    ContentUnavailableView(
                        "No Injury Records",
                        systemImage: "bandage.fill",
                        description: Text("Injuries you track will appear here.")
                    )
                }
            }
        }
        .onChange(of: allRecords.count) { _, _ in rebuildRecordCache() }
        .onChange(of: allRecords.map(\.endDate)) { _, _ in rebuildRecordCache() }
        .onAppear { rebuildRecordCache() }
        .scrollContentBackground(.hidden)
        .background { DetailWaveBackground() }
        .environment(\.waveColor, DS.Color.caution)
        .englishNavigationTitle("Injury History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.loadStatistics(from: allRecords)
                    showingStatistics = true
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                }
                .accessibilityIdentifier("injury-history-stats")
                .tint(statisticsTint)
                .disabled(allRecords.isEmpty)
            }
        }
        .navigationDestination(isPresented: $showingStatistics) {
            // Correction #48: avoid conditional content inside navigationDestination
            InjuryStatisticsView(
                statistics: viewModel.statistics ?? InjuryStatistics(
                    totalCount: 0,
                    activeCount: 0,
                    frequencyByBodyPart: [],
                    averageRecoveryDays: nil,
                    longestRecoveryDays: nil
                ),
                volumeComparisons: viewModel.volumeComparisons
            )
        }
        .navigationDestination(item: $selectedInjury) { destination in
            InjuryDetailView(record: allRecords.first { $0.id == destination.recordID })
        }
        .sheet(isPresented: $viewModel.isShowingEditSheet) {
            if viewModel.editingRecord != nil {
                InjuryFormSheet(
                    viewModel: viewModel,
                    isEdit: true,
                    onSave: {
                        if let record = viewModel.editingRecord, viewModel.applyUpdate(to: record) {
                            viewModel.isShowingEditSheet = false
                            viewModel.resetForm()
                        }
                    }
                )
            }
        }
        .confirmationDialog(
            "Delete Injury",
            isPresented: Binding(
                get: { recordToDelete != nil },
                set: { if !$0 { recordToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let record = recordToDelete {
                    withAnimation { modelContext.delete(record) }
                    recordToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                recordToDelete = nil
            }
        } message: {
            Text("This injury record will be permanently deleted across all your devices.")
        }
    }

    private func rebuildRecordCache() {
        cachedActiveRecords = allRecords.filter(\.isActive)
        cachedEndedRecords = allRecords.filter { !$0.isActive }
    }

    private func injuryRow(_ record: InjuryRecord) -> some View {
        let recordID = record.id
        return Button {
            selectedInjury = InjuryDetailDestination(recordID: recordID)
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                injuryRowContent(record)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(rowIdentifier(for: record))
        .swipeActions(edge: .trailing) {
            Button { recordToDelete = record } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)

            if record.isActive {
                Button {
                    withAnimation { viewModel.markAsRecovered(record) }
                } label: {
                    Label("Recovered", systemImage: "checkmark.circle")
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .leading) {
            Button { viewModel.startEditing(record) } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button { viewModel.startEditing(record) } label: {
                Label("Edit", systemImage: "pencil")
            }
            if record.isActive {
                Button {
                    withAnimation { viewModel.markAsRecovered(record) }
                } label: {
                    Label("Mark Recovered", systemImage: "checkmark.circle")
                }
            }
            Divider()
            Button(role: .destructive) { recordToDelete = record } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var statisticsTint: Color {
        colorScheme == .light ? theme.accentColor.mix(with: .black, by: 0.45) : theme.accentColor
    }

    private func severityForeground(_ severity: InjurySeverity) -> Color {
        colorScheme == .light ? severity.color.mix(with: .black, by: 0.45) : severity.color
    }

    private func injuryRowContent(_ record: InjuryRecord) -> some View {
        let rowLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
        let metadataLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.xs))

        return rowLayout {
            Image(systemName: record.severity.iconName)
                .font(.title3)
                .foregroundStyle(severityForeground(record.severity))
                .frame(width: rowIconWidth)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                metadataLayout {
                    Text(record.bodyPart.displayName)
                        .font(.headline)
                    if let side = record.bodySide {
                        Text("(\(side.abbreviation))")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }

                metadataLayout {
                    Text(record.severity.displayName)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text("·")
                            .foregroundStyle(.quaternary)
                    }
                    Text(record.durationLabel)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                Text(record.dateRangeLabel)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            if record.isActive {
                Text("Active")
                    .font(.caption2.weight(.medium))
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(record.severity.color.opacity(0.12), in: Capsule())
                    .foregroundStyle(.primary)
            }
        }
    }

    private func rowIdentifier(for record: InjuryRecord) -> String {
        let index = allRecords.firstIndex { $0.id == record.id } ?? 0
        return "injury-history-row-\(index)"
    }
}

private struct InjuryDetailDestination: Hashable {
    let recordID: UUID
}

private struct InjuryDetailView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .title2) private var heroIconSize: CGFloat = 44
    let record: InjuryRecord?
    @State private var detailViewModel = InjuryViewModel()
    @State private var isShowingEditSheet = false

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("injury-detail-screen")

            Group {
                if let record {
                    ScrollView {
                        VStack(spacing: DS.Spacing.lg) {
                            summaryCard(record)
                            timelineCard(record)
                            notesCard(record)
                        }
                        .padding(DS.Spacing.lg)
                    }
                    .accessibilityIdentifier("injury-detail-scroll")
                } else {
                    ContentUnavailableView(
                        "Injury Not Found",
                        systemImage: "bandage.fill",
                        description: Text("This injury may have been deleted.")
                    )
                }
            }
        }
        .background { DetailWaveBackground() }
        .environment(\.waveColor, DS.Color.caution)
        .englishNavigationTitle("Injury Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let record {
                ToolbarItemGroup(placement: .primaryAction) {
                    if record.isActive {
                        Button {
                            withAnimation { detailViewModel.markAsRecovered(record) }
                        } label: {
                            Label("Mark Recovered", systemImage: "checkmark.circle")
                        }
                        .accessibilityIdentifier("injury-detail-mark-recovered")
                        .tint(colorScheme == .light ? theme.accentColor.mix(with: .black, by: 0.45) : theme.accentColor)
                    }

                    Button {
                        detailViewModel.startEditing(record)
                        isShowingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("injury-detail-edit")
                    .tint(colorScheme == .light ? theme.accentColor.mix(with: .black, by: 0.45) : theme.accentColor)
                }
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            if let record {
                InjuryFormSheet(
                    viewModel: detailViewModel,
                    isEdit: true,
                    onSave: {
                        if detailViewModel.applyUpdate(to: record) {
                            isShowingEditSheet = false
                            detailViewModel.resetForm()
                        }
                    }
                )
            }
        }
    }

    private func summaryCard(_ record: InjuryRecord) -> some View {
        HeroCard(tintColor: record.severity.color) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Image(systemName: record.severity.iconName)
                    .font(.system(size: heroIconSize, weight: .medium))
                    .foregroundStyle(severityForeground(record))
                    .padding(DS.Spacing.md)
                    .background(record.severity.color.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(record.bodyPart.displayName)
                        .font(.title2.bold())
                        .accessibilityIdentifier("injury-detail-body-part")
                    if let side = record.bodySide {
                        Text("(\(side.displayName))")
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                            .accessibilityIdentifier("injury-detail-side")
                    }
                    Text(record.severity.displayName)
                        .font(.headline)
                        .accessibilityIdentifier("injury-detail-severity")
                }

                Label(
                    record.isActive ? String(localized: "Active") : String(localized: "Recovered"),
                    systemImage: record.isActive ? "bandage.fill" : "checkmark.circle"
                )
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background((record.isActive ? record.severity.color : Color.green).opacity(0.12), in: Capsule())
                .accessibilityIdentifier("injury-detail-status")

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Label("Duration", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                    Text("\(record.durationDays) days")
                        .font(DS.Typography.heroScore)
                        .accessibilityIdentifier("injury-detail-duration")
                }

                Text(record.severity.severityDescription)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .accessibilityIdentifier("injury-detail-description")
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("injury-detail-summary")
    }

    private func severityForeground(_ record: InjuryRecord) -> Color {
        colorScheme == .light
            ? record.severity.color.mix(with: .black, by: 0.45)
            : record.severity.color
    }

    private func timelineCard(_ record: InjuryRecord) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Timeline", systemImage: "calendar")
                    .font(DS.Typography.sectionTitle)

                detailRow("Start", symbol: "calendar", value: record.startDate.formatted(date: .abbreviated, time: .omitted), identifier: "injury-detail-start-value")
                detailRow("End", symbol: "calendar.badge.checkmark", value: record.endDate?.formatted(date: .abbreviated, time: .omitted) ?? String(localized: "Ongoing"), identifier: "injury-detail-end-value")
                detailRow("Recorded", symbol: "clock", value: record.createdAt.formatted(date: .abbreviated, time: .shortened), identifier: "injury-detail-recorded-value")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("injury-detail-timeline")
    }

    private func notesCard(_ record: InjuryRecord) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Memo", systemImage: "note.text")
                    .font(DS.Typography.sectionTitle)

                if record.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No memo")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .accessibilityIdentifier("injury-detail-memo-value")
                } else {
                    Text(record.memo)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("injury-detail-memo-value")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("injury-detail-memo")
    }

    private func detailRow(_ title: LocalizedStringKey, symbol: String, value: String, identifier: String) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.md))
        return layout {
            Label(title, systemImage: symbol)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                .accessibilityIdentifier(identifier)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
