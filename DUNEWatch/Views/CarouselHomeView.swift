import SwiftUI
import SwiftData

// MARK: - Carousel Card Model

/// Represents a single card in the carousel home.
struct CarouselCard: Identifiable, Hashable {
    let id: String
    let section: Section
    let content: Content

    enum Section: String {
        case routine
        case popular
        case recent
        case allExercises

        /// Section label for display (Correction #93 — exhaustive switch, no default).
        var label: String {
            switch self {
            case .routine: return "Routine"
            case .popular: return "Popular"
            case .recent: return "Recent"
            case .allExercises: return "Browse"
            }
        }

        /// Section accent color.
        var color: Color {
            switch self {
            case .routine: return DS.Color.warmGlow
            case .popular: return DS.Color.positive
            case .recent: return .secondary
            case .allExercises: return .secondary
            }
        }
    }

    enum Content: Hashable {
        case exercise(WatchExerciseInfo, snapshot: WorkoutSessionTemplate, daysAgo: String?)
        case routine(name: String, entries: [TemplateEntry])
        case allExercises

        // Correction #26: == and hash must use the same fields
        func hash(into hasher: inout Hasher) {
            switch self {
            case .exercise(let info, _, _):
                hasher.combine("exercise")
                hasher.combine(info.id)
            case .routine(let name, let entries):
                hasher.combine("routine")
                hasher.combine(name)
                entries.forEach { hasher.combine($0.id) }
            case .allExercises:
                hasher.combine("all")
            }
        }

        static func == (lhs: Content, rhs: Content) -> Bool {
            switch (lhs, rhs) {
            case (.exercise(let a, _, _), .exercise(let b, _, _)):
                return a.id == b.id
            case (.routine(let aName, let aEntries), .routine(let bName, let bEntries)):
                return aName == bName && aEntries.map(\.id) == bEntries.map(\.id)
            case (.allExercises, .allExercises):
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - Carousel Home View

/// Unified Watch home: fullscreen paging carousel combining Routines + Popular + Recent.
/// Replaces the separate RoutineListView + QuickStartPickerView.
struct CarouselHomeView: View {
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Environment(WatchConnectivityManager.self) private var connectivity

    @State private var cards: [CarouselCard] = []
    /// Content-aware invalidation key (Correction #87).
    @State private var templateContentKey: Int = 0

    private let popularLimit = 20
    private let recentLimit = 20

    var body: some View {
        Group {
            if cards.isEmpty {
                emptyState
            } else {
                carousel
            }
        }
        .background { WatchWaveBackground() }
        .navigationTitle("DUNE")
        .onAppear {
            updateTemplateContentKey()
            rebuildCards()
        }
        .onChange(of: templateContentKey) { _, _ in rebuildCards() }
        .onChange(of: templates.count) { _, _ in updateTemplateContentKey() }
        .onChange(of: connectivity.exerciseLibrary.count) { _, _ in rebuildCards() }
    }

    /// Computes a content-aware hash of all templates (Correction #87).
    private func updateTemplateContentKey() {
        var hasher = Hasher()
        for t in templates {
            hasher.combine(t.id)
            hasher.combine(t.name)
            hasher.combine(t.updatedAt)
        }
        let newKey = hasher.finalize()
        if newKey != templateContentKey {
            templateContentKey = newKey
        }
    }

    // MARK: - Carousel

    private var carousel: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(cards) { card in
                    cardContent(for: card)
                        .containerRelativeFrame(.vertical)
                        .scrollTransition { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                                .opacity(phase.isIdentity ? 1.0 : 0.6)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
    }

    // MARK: - Card Content

    @ViewBuilder
    private func cardContent(for card: CarouselCard) -> some View {
        switch card.content {
        case .exercise(let exercise, let snapshot, let daysAgo):
            NavigationLink(value: WatchRoute.workoutPreview(snapshot)) {
                ExerciseCardView(
                    exercise: exercise,
                    sectionLabel: card.section.label,
                    sectionColor: card.section.color,
                    daysAgo: daysAgo
                )
            }
            .buttonStyle(.plain)

        case .routine(let name, let entries):
            NavigationLink(value: WatchRoute.workoutPreview(
                WorkoutSessionTemplate(name: name, entries: entries)
            )) {
                CarouselRoutineCardView(name: name, entries: entries)
            }
            .buttonStyle(.plain)

        case .allExercises:
            NavigationLink(value: WatchRoute.quickStartAll) {
                allExercisesCard
            }
            .buttonStyle(.plain)
        }
    }

    private var allExercisesCard: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("BROWSE")
                .font(DS.Typography.tinyLabel)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(DS.Color.positive)

            Text("All Exercises")
                .font(.system(.title3, design: .rounded).bold())

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "iphone.and.arrow.right.inward")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No Exercises")
                .font(DS.Typography.exerciseName)
            Text("Open the DUNE app\non your iPhone to sync")
                .font(DS.Typography.metricLabel)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink(value: WatchRoute.quickStartAll) {
                Label("Browse All", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.positive)
            .padding(.top, DS.Spacing.md)

            syncStatusView
                .padding(.top, DS.Spacing.xs)
        }
        .padding()
    }

    // MARK: - Sync Status

    private var syncStatusView: some View {
        HStack(spacing: 4) {
            switch connectivity.syncStatus {
            case .syncing:
                ProgressView()
                    .frame(width: 12, height: 12)
                Text("Syncing...")
            case .synced(let date):
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(DS.Color.positive)
                Text(syncTimeLabel(from: date))
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(DS.Color.caution)
                Text(message)
            case .notConnected:
                Image(systemName: "iphone.slash")
                    .foregroundStyle(.secondary)
                Text("iPhone not connected")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func syncTimeLabel(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just synced"
        } else if interval < 3600 {
            return "\(Int(interval / 60).formattedWithSeparator) min ago"
        } else {
            return "\(Int(interval / 3600).formattedWithSeparator)h ago"
        }
    }

    // MARK: - Rebuild Cards

    /// Builds carousel card array: Routines → Popular → Recent → All Exercises.
    /// Pre-computes snapshots and daysAgo to avoid UserDefaults reads in body (P1 #2, P2 #5).
    /// @State caching with onChange invalidation (Correction #47, #87).
    private func rebuildCards() {
        var result: [CarouselCard] = []
        let library = connectivity.exerciseLibrary

        // Build equipment lookup for enriching legacy template entries (equipment == nil).
        // Keys only present when equipment is non-nil and non-empty.
        var equipmentByID: [String: String] = [:]
        for exercise in library {
            guard let eq = exercise.equipment, !eq.isEmpty else { continue }
            equipmentByID[exercise.id] = eq
        }

        // 1. Routine cards (most recently updated first)
        for template in templates {
            let entries = Self.enrichedEntries(template.exerciseEntries, equipmentByID: equipmentByID)
            result.append(CarouselCard(
                id: "routine-\(template.id)",
                section: .routine,
                content: .routine(name: template.name, entries: entries)
            ))
        }

        // 2. Popular exercises
        guard !library.isEmpty else {
            // No library synced — show routines (if any) + all exercises card
            result.append(CarouselCard(
                id: "all-exercises",
                section: .allExercises,
                content: .allExercises
            ))
            cards = result
            return
        }

        let popular = Array(
            uniqueByCanonical(
                RecentExerciseTracker.personalizedPopular(from: library, limit: popularLimit)
            )
            .prefix(popularLimit)
        )

        let popularCanonical = Set(
            popular.map { RecentExerciseTracker.canonicalExerciseID(exerciseID: $0.id) }
        )

        for exercise in popular {
            result.append(exerciseCard(exercise, section: .popular))
        }

        // 3. Recent exercises (excluding Popular)
        let lastUsed = RecentExerciseTracker.lastUsedTimestamps()
        let recent = Array(
            uniqueByCanonical(
                library
                    .filter { lastUsed[$0.id] != nil }
                    .sorted {
                        let a = lastUsed[$0.id] ?? Date.distantPast.timeIntervalSince1970
                        let b = lastUsed[$1.id] ?? Date.distantPast.timeIntervalSince1970
                        return a > b
                    }
            )
            .filter { !popularCanonical.contains(RecentExerciseTracker.canonicalExerciseID(exerciseID: $0.id)) }
            .prefix(recentLimit)
        )

        for exercise in recent {
            result.append(exerciseCard(exercise, section: .recent))
        }

        // 4. All Exercises card (always last)
        result.append(CarouselCard(
            id: "all-exercises",
            section: .allExercises,
            content: .allExercises
        ))

        cards = result
    }

    /// Pre-builds a CarouselCard with snapshot + daysAgo resolved at build time.
    private func exerciseCard(_ exercise: WatchExerciseInfo, section: CarouselCard.Section) -> CarouselCard {
        let snapshot = snapshotFromExercise(exercise)
        let daysAgo = daysAgoLabel(for: exercise)
        return CarouselCard(
            id: "\(section.rawValue)-\(exercise.id)",
            section: section,
            content: .exercise(exercise, snapshot: snapshot, daysAgo: daysAgo)
        )
    }

    /// Enriches template entries with equipment from exercise library when equipment is nil.
    /// Handles legacy entries created before the equipment field was added to TemplateEntry.
    /// NOTE: Relies on TemplateEntry being a value type (struct) for copy-on-write mutation.
    private static func enrichedEntries(
        _ entries: [TemplateEntry],
        equipmentByID: [String: String]
    ) -> [TemplateEntry] {
        entries.map { entry in
            guard entry.equipment == nil else { return entry }
            guard let equipment = equipmentByID[entry.exerciseDefinitionID] else { return entry }
            var enriched = entry
            enriched.equipment = equipment
            return enriched
        }
    }

    /// Computes "N days ago" label at card-build time (not in body).
    private func daysAgoLabel(for exercise: WatchExerciseInfo) -> String? {
        guard !exercise.id.isEmpty,
              let lastDate = RecentExerciseTracker.lastUsed(exerciseID: exercise.id) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }
}
