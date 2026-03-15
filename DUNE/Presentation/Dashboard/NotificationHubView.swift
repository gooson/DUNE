import SwiftUI

enum NotificationHubMetricResolver {
    private static let firstNumberRegex = try! NSRegularExpression(pattern: #"[-+]?\d+(?:[.,]\d+)*"#)
    private static let sleepHourMinuteRegex = [
        try! NSRegularExpression(pattern: #"(\d+)\s*h\s*(\d+)\s*m"#, options: [.caseInsensitive]),
        try! NSRegularExpression(pattern: #"(\d+)\s*시간\s*(\d+)\s*분"#)
    ]
    private static let sleepHourRegex = [
        try! NSRegularExpression(pattern: #"(\d+)\s*h"#, options: [.caseInsensitive]),
        try! NSRegularExpression(pattern: #"(\d+)\s*시간"#)
    ]
    private static let sleepMinuteRegex = [
        try! NSRegularExpression(pattern: #"(\d+)\s*m"#, options: [.caseInsensitive]),
        try! NSRegularExpression(pattern: #"(\d+)\s*분"#)
    ]

    static func category(for insightType: HealthInsight.InsightType) -> HealthMetric.Category? {
        switch insightType {
        case .hrvAnomaly:
            .hrv
        case .rhrAnomaly:
            .rhr
        case .sleepComplete, .sleepDebt:
            .sleep
        case .stepGoal:
            .steps
        case .weightUpdate:
            .weight
        case .bodyFatUpdate:
            .bodyFat
        case .bmiUpdate:
            .bmi
        case .workoutPR:
            .exercise
        case .lifeChecklistReminder:
            nil
        case .postureReminder:
            nil
        }
    }

    static func metric(for item: NotificationInboxItem) -> HealthMetric? {
        guard let category = category(for: item.insightType) else { return nil }

        let parsedValue = metricValue(for: item)
        let unit = switch category {
        case .sleep, .bmi:
            ""
        default:
            category.unitLabel
        }

        return HealthMetric(
            id: "notification-\(item.id)",
            name: category.displayName,
            value: parsedValue ?? 0,
            unit: unit,
            change: nil,
            date: item.createdAt,
            category: category,
            isHistorical: true
        )
    }

    private static func metricValue(for item: NotificationInboxItem) -> Double? {
        switch item.insightType {
        case .sleepComplete, .sleepDebt:
            parseSleepMinutes(in: item.body)
        case .workoutPR:
            // Legacy workout notifications might not have route payload.
            // Keep destination available without guessing a potentially wrong value.
            nil
        case .lifeChecklistReminder:
            nil
        default:
            firstNumber(in: item.body)
        }
    }

    private static func parseSleepMinutes(in text: String) -> Double? {
        for regex in sleepHourMinuteRegex {
            if let pair = integerPair(in: text, with: regex) {
                return Double(pair.0 * 60 + pair.1)
            }
        }

        for regex in sleepHourRegex {
            if let hours = firstInteger(in: text, with: regex) {
                return Double(hours * 60)
            }
        }

        for regex in sleepMinuteRegex {
            if let minutes = firstInteger(in: text, with: regex) {
                return Double(minutes)
            }
        }

        return firstNumber(in: text)
    }

    private static func firstNumber(in text: String) -> Double? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = firstNumberRegex.firstMatch(in: text, range: range),
              let numberRange = Range(match.range(at: 0), in: text) else {
            return nil
        }
        return parseNormalizedNumber(String(text[numberRange]))
    }

    private static func parseNormalizedNumber(_ numberText: String) -> Double? {
        let normalizedNumberText = numberText.replacingOccurrences(of: " ", with: "")

        if normalizedNumberText.contains("."), normalizedNumberText.contains(",") {
            return Double(normalizedNumberText.replacingOccurrences(of: ",", with: ""))
        }

        if normalizedNumberText.contains(",") {
            let components = normalizedNumberText.split(separator: ",")
            if components.count == 2, components[1].count <= 2 {
                return Double(normalizedNumberText.replacingOccurrences(of: ",", with: "."))
            }
            return Double(normalizedNumberText.replacingOccurrences(of: ",", with: ""))
        }

        return Double(normalizedNumberText)
    }

    private static func integerPair(in text: String, with regex: NSRegularExpression) -> (Int, Int)? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let firstRange = Range(match.range(at: 1), in: text),
              let secondRange = Range(match.range(at: 2), in: text),
              let firstValue = Int(text[firstRange]),
              let secondValue = Int(text[secondRange]) else {
            return nil
        }
        return (firstValue, secondValue)
    }

    private static func firstInteger(in text: String, with regex: NSRegularExpression) -> Int? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[valueRange])
    }
}

/// Latest-first notification inbox accessed from the Today tab toolbar.
struct NotificationHubView: View {
    let sharedHealthDataService: SharedHealthDataService?

    @State private var items: [NotificationInboxItem] = []
    @State private var unreadCount = 0
    @State private var destination: HubDestination?
    @State private var showDeleteAllConfirmation = false
    @State private var animatedIDs: Set<String> = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let inboxManager = NotificationInboxManager.shared

    init(sharedHealthDataService: SharedHealthDataService? = nil) {
        self.sharedHealthDataService = sharedHealthDataService
    }

    private enum HubDestination: Hashable, Identifiable {
        case metric(HealthMetric, itemID: String)
        case settings
        case unavailable(itemID: String)
        case personalRecords(itemID: String)

        var id: String {
            switch self {
            case .metric(let metric, let itemID):
                let category = metric.category
                return "metric-\(category.rawValue)-\(itemID)"
            case .settings:
                return "settings"
            case .unavailable(let itemID):
                return "unavailable-\(itemID)"
            case .personalRecords(let itemID):
                return "personal-records-\(itemID)"
            }
        }
    }

    var body: some View {
        List {
            summarySection

            if items.isEmpty {
                emptySection
            } else {
                inboxSection
            }
        }
        .accessibilityIdentifier("notification-hub-screen")
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background { TabWaveBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .englishNavigationTitle("Notifications")
        .confirmationDialog("Delete all notifications?", isPresented: $showDeleteAllConfirmation, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                inboxManager.deleteAll()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action removes every notification from your inbox.")
        }
        .navigationDestination(item: $destination) { target in
            switch target {
            case .metric(let metric, _):
                MetricDetailView(metric: metric)
            case .settings:
                SettingsView()
            case .unavailable(let itemID):
                NotificationDestinationUnavailableView(itemID: itemID)
            case .personalRecords:
                NotificationPersonalRecordsPushView(sharedHealthDataService: sharedHealthDataService)
            }
        }
        .task {
            reload()
        }
        .onReceive(NotificationCenter.default.mainThreadPublisher(for: NotificationInboxManager.inboxDidChangeNotification)) { _ in
            reload()
        }
    }

    private var summarySection: some View {
        Section {
            StandardCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell")
                            .font(.headline)
                            .foregroundStyle(.tint)

                        if unreadCount > 0 {
                            Text("\(unreadCount) unread notifications")
                                .font(.subheadline.weight(.semibold))
                        } else {
                            Text("Inbox is all caught up")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .layoutPriority(1)
                        }

                        Spacer()

                        Button {
                            destination = .settings
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Notification Settings")
                        .accessibilityIdentifier("notifications-open-settings-button")
                    }

                    HStack(spacing: DS.Spacing.sm) {
                        Button("Read All") {
                            inboxManager.markAllRead()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(unreadCount == 0)
                        .accessibilityIdentifier("notifications-read-all-button")

                        Button("Delete All", role: .destructive) {
                            showDeleteAllConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(items.isEmpty)
                        .accessibilityIdentifier("notifications-delete-all-button")
                    }
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: DS.Spacing.sm, leading: DS.Spacing.lg, bottom: DS.Spacing.sm, trailing: DS.Spacing.lg))
        }
    }

    private var emptySection: some View {
        Section {
            EmptyStateView(
                icon: "bell.slash",
                title: "No Notifications",
                message: "Notifications will appear here when they arrive.",
                actionTitle: "Open Settings",
                action: { destination = .settings }
            )
            .accessibilityIdentifier("notifications-empty-state")
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: DS.Spacing.sm, leading: DS.Spacing.lg, bottom: DS.Spacing.sm, trailing: DS.Spacing.lg))
        }
    }

    private var inboxSection: some View {
        Section {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    handleTap(on: item)
                } label: {
                    notificationRow(for: item, index: index)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(notificationRowAccessibilityIdentifier(for: item))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button(item.isRead ? "Unread" : "Read") {
                        item.isRead ? inboxManager.markUnread(id: item.id) : inboxManager.markRead(id: item.id)
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive) {
                        _ = inboxManager.delete(id: item.id)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: DS.Spacing.xs, leading: DS.Spacing.lg, bottom: DS.Spacing.xs, trailing: DS.Spacing.lg))
            }
        }
    }

    private func reload() {
        items = inboxManager.items()
        unreadCount = inboxManager.unreadCount()
    }

    private func handleTap(on item: NotificationInboxItem) {
        // Routes that need tab switch (workoutDetail) use open() → ContentView handles via notification
        // Routes that can be handled locally use openLocally() → no navigation request emitted
        let isLocalRoute = item.route?.destination == .activityPersonalRecords
            || (item.route == nil && item.insightType == .workoutPR)

        if isLocalRoute {
            guard let opened = inboxManager.openLocally(itemID: item.id) else {
                destination = .unavailable(itemID: item.id)
                return
            }
            destination = .personalRecords(itemID: opened.id)
            return
        }

        guard let opened = inboxManager.open(itemID: item.id) else {
            destination = .unavailable(itemID: item.id)
            return
        }

        // Other routes (workoutDetail) → delegate to ContentView for tab switch
        guard opened.route == nil else {
            return
        }

        if let metric = NotificationHubMetricResolver.metric(for: opened) {
            destination = .metric(metric, itemID: opened.id)
        } else {
            destination = .unavailable(itemID: opened.id)
        }
    }

    private func notificationRow(for item: NotificationInboxItem, index: Int) -> some View {
        let hint = destinationHint(for: item)

        return InlineCard {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(iconTint(for: item.insightType).opacity(0.18))
                        .frame(width: 30, height: 30)

                    Image(systemName: item.insightType.settingsIcon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(iconTint(for: item.insightType))
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        if !item.isRead {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 7, height: 7)
                        }

                        Spacer()

                        Text(item.createdAt, format: .relative(presentation: .named))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.body)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Label(hint.title, systemImage: hint.symbol)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .stroke(item.isRead ? Color.clear : Color.accentColor.opacity(0.30), lineWidth: 1)
        }
        .opacity(reduceMotion || animatedIDs.contains(item.id) ? 1 : 0)
        .offset(y: reduceMotion || animatedIDs.contains(item.id) ? 0 : 10)
        .onAppear {
            animateRowIfNeeded(itemID: item.id, index: index)
        }
    }

    private func animateRowIfNeeded(itemID: String, index: Int) {
        guard !animatedIDs.contains(itemID) else { return }
        guard !reduceMotion else {
            animatedIDs.insert(itemID)
            return
        }

        let delay = min(Double(index), 12) * 0.035
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(DS.Animation.standard) {
                _ = animatedIDs.insert(itemID)
            }
        }
    }

    private func destinationHint(for item: NotificationInboxItem) -> (title: String, symbol: String) {
        if item.route?.destination == .workoutDetail {
            return (String(localized: "Workout Detail"), "figure.strengthtraining.traditional")
        }
        if item.route?.destination == .activityPersonalRecords || item.insightType == .workoutPR {
            return (String(localized: "Personal Records"), "trophy.fill")
        }

        guard let category = NotificationHubMetricResolver.category(for: item.insightType) else {
            return (String(localized: "Notification Detail"), "arrow.triangle.branch")
        }

        return (String(localized: "\(category.displayName) Detail"), category.iconName)
    }

    private func notificationRowAccessibilityIdentifier(for item: NotificationInboxItem) -> String {
        if item.route?.destination == .workoutDetail,
           let workoutID = item.route?.workoutID,
           !workoutID.isEmpty {
            return "notification-row-workout-\(workoutID)"
        }

        return "notification-row-\(item.id)"
    }

    private func iconTint(for type: HealthInsight.InsightType) -> Color {
        switch type {
        case .hrvAnomaly:
            DS.Color.hrv
        case .rhrAnomaly:
            DS.Color.rhr
        case .sleepComplete, .sleepDebt:
            DS.Color.sleep
        case .stepGoal:
            DS.Color.steps
        case .weightUpdate, .bodyFatUpdate, .bmiUpdate:
            DS.Color.body
        case .workoutPR:
            DS.Color.activity
        case .lifeChecklistReminder:
            DS.Color.tabLife
        case .postureReminder:
            DS.Color.body
        }
    }
}

private struct NotificationDestinationUnavailableView: View {
    let itemID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EmptyStateView(
            icon: "arrow.triangle.branch",
            title: "Destination Unavailable",
            message: "Could not find where this notification should open. Check your notification settings.",
            actionTitle: "Go Back",
            action: {
                dismiss()
            }
        )
        .padding(.horizontal, DS.Spacing.lg)
        .background { DetailWaveBackground() }
        .overlay(alignment: .bottom) {
            Text("ID: \(itemID)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, DS.Spacing.lg)
        }
        .englishNavigationTitle("Notification")
    }
}

#Preview {
    NavigationStack {
        NotificationHubView()
    }
}
