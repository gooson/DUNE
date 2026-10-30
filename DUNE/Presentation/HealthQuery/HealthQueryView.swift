import SwiftUI
import UIKit

struct HealthQueryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: HealthQueryViewModel
    private let queryService: any HealthQuerying
    @State private var kind: HealthQueryKind
    @State private var period: HealthQueryPeriod?
    @State private var request: HealthQueryRequest
    @State private var searchText: String

    init(queryService: any HealthQuerying, request: HealthQueryRequest? = nil) {
        self.queryService = queryService
        _model = State(initialValue: HealthQueryViewModel(service: queryService))
        _kind = State(initialValue: request?.kind ?? .latestWorkout)
        _request = State(initialValue: request ?? HealthQueryRequest(kind: .latestWorkout))
        let selected = request?.interval.flatMap { incoming in
            HealthQueryPeriod.allCases.first { candidate in
                let generated = candidate.interval(endingAt: .now)
                return abs(generated.start.timeIntervalSince(incoming.start)) < 60
                    && abs(generated.end.timeIntervalSince(incoming.end)) < 60
            }
        }
        _period = State(initialValue: request == nil ? .last30Days : selected)
        _searchText = State(initialValue: request?.searchText ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("Health information")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("health-query-screen")
                Picker("Information", selection: $kind) {
                    ForEach(HealthQueryKind.allCases, id: \.self) { item in
                        Text(item.displayName).tag(item)
                            .accessibilityIdentifier("health-query-kind-\(item.rawValue)")
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("health-query-kind")
                Picker("Period", selection: $period) {
                    if period == nil { Text("Custom period").tag(nil as HealthQueryPeriod?) }
                    ForEach(HealthQueryPeriod.allCases, id: \.self) { item in
                        Text(item.displayName).tag(item as HealthQueryPeriod?)
                            .accessibilityIdentifier("health-query-period-\(item.rawValue)")
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("health-query-period")
                if kind == .memoSearch {
                    HStack {
                        TextField("Search workout notes", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.search)
                            .onSubmit { load() }
                            .accessibilityIdentifier("health-query-search-field")
                        Button("Search") { load() }
                            .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("health-query-search-submit")
                    }
                }

                switch model.state {
                case .idle:
                    Text("Enter words from a workout note to search your records.")
                        .foregroundStyle(DS.Color.textSecondary)
                case .loading:
                    InlineCard {
                        HStack(spacing: DS.Spacing.sm) {
                            ProgressView()
                            Text("Reading health records...")
                        }
                    }
                    Button("Cancel analysis") { model.cancel() }
                        .accessibilityIdentifier("health-query-cancel")
                case .loaded(let result):
                    HealthQueryResultCard(result: result, queryService: queryService)
                        .accessibilityIdentifier("health-query-result")
                    if result.status == .unavailable || result.status == .invalidRequest {
                        Button("Try again") { load() }
                            .accessibilityIdentifier("health-query-retry")
                    }
                    if result.status == .noData {
                        Text("Choose another period to look for records.")
                            .font(.footnote).foregroundStyle(DS.Color.textSecondary)
                    }
                    if (result.status == .available || result.status == .partial),
                       !result.sources.isEmpty,
                       result.metrics.contains(where: { $0.value.isFinite && $0.comparisonValue?.isFinite == true }) {
                        Button("Explain comparison") { model.explainComparison() }
                            .disabled(model.isExplaining)
                        if model.isExplaining { ProgressView("Explaining comparison...") }
                        if let message = model.explanationMessage {
                            Text(message).font(.footnote).foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                case .failed(let message):
                    ContentUnavailableView(message, systemImage: "exclamationmark.circle")
                    Button("Try again") { load() }
                case .cancelled:
                    ContentUnavailableView("Analysis cancelled", systemImage: "xmark.circle")
                    Button("Try again") { load() }
                }
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background { SheetWaveBackground() }
        .navigationTitle("Health information")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("health-query-done")
            }
        }
        .task {
            if kind == .memoSearch && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                model.clear()
            } else { load() }
        }
        .onChange(of: kind) { _, newKind in
            request.kind = newKind
            request.workoutID = nil
            request.exerciseID = nil
            request.comparisonInterval = nil
            request.searchText = nil
            if period == nil { period = .last30Days }
            if newKind == .memoSearch && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { model.clear() }
            else { load() }
        }
        .onChange(of: period) { _, selected in
            if let selected { request.interval = selected.interval(endingAt: .now) }
            if kind != .memoSearch || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { load() }
        }
        .onDisappear { model.cancel() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            if case .loaded(let result) = model.state, result.status == .locked { load() }
        }
    }

    private func load() {
        request.kind = kind
        request.searchText = kind == .memoSearch ? searchText.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        if kind == .memoSearch && request.searchText?.isEmpty != false { model.clear(); return }
        if request.interval == nil {
            request.interval = (period ?? .last30Days).interval(endingAt: .now)
        }
        model.load(request)
    }
}

#Preview {
    NavigationStack {
        HealthQueryView(queryService: PreviewHealthQueryService())
    }
}

@MainActor private struct PreviewHealthQueryService: HealthQuerying {
    func execute(_ request: HealthQueryRequest) async throws -> HealthQueryResult {
        HealthQueryResult(kind: request.kind, status: .noData, title: request.kind.displayName,
                          generatedAt: .now, interval: request.interval ?? HealthQueryPeriod.today.interval(endingAt: .now),
                          spokenSummary: "")
    }
}
