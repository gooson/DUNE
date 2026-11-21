import SwiftUI

enum SettingsHubRoute: Hashable, Identifiable {
    case home, search, gallery, preview(AppTheme), icons
    case workout, exerciseDefaults, preferredExercises, liveActivity
    case alerts, healthAlerts, bedtime, otherAlerts, privacy, about, news, mockData

    var id: Self { self }

    var navigationTitle: String {
        switch self {
        case .home: "Settings"
        case .search: "Search Settings"
        case .gallery: "Themes"
        case .preview: "Theme Preview"
        case .icons: "App Icon"
        case .workout: "Workout Settings"
        case .exerciseDefaults: "Exercise Defaults"
        case .preferredExercises: "Preferred Exercises"
        case .liveActivity: "Workout Live Activity"
        case .alerts: "Notifications & Briefing"
        case .healthAlerts: "Health Alerts"
        case .bedtime: "Bedtime"
        case .otherAlerts: "Other Alerts"
        case .privacy: "Data & Privacy"
        case .about: "About"
        case .news: "Notifications"
        case .mockData: "Mock Data"
        }
    }

    var category: Self {
        switch self {
        case .preview: .gallery
        case .liveActivity, .exerciseDefaults, .preferredExercises: .workout
        case .healthAlerts, .bedtime, .otherAlerts: .alerts
        case .news: .about
        default: self
        }
    }
}

struct SettingsView: View {
    let sharedHealthDataService: SharedHealthDataService?
    let canLoadHealthKitData: Bool
    let hasFailedHealthKitAuthorization: Bool
    private let entry: SettingsHubRoute

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        canLoadHealthKitData: Bool = true,
        hasFailedHealthKitAuthorization: Bool = false,
        entry: SettingsHubRoute = .home
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.canLoadHealthKitData = canLoadHealthKitData
        self.hasFailedHealthKitAuthorization = hasFailedHealthKitAuthorization
        self.entry = entry
    }

    @Environment(\.dismiss) private var dismiss
    @State private var pushed: SettingsHubRoute?
    @State private var columnHistory: [SettingsHubRoute] = []
    @State private var searchQuery = ""

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 700
            let current = columnHistory.last ?? entry
            Group {
                if wide {
                    HStack(spacing: 0) {
                        home(selection: current == .home ? .gallery : current.category) { route in
                            searchQuery = ""
                            columnHistory = [route]
                        }
                        .frame(width: min(340, proxy.size.width * 0.38))
                        Divider()
                        column(current == .home ? .gallery : current)
                    }
                } else if !columnHistory.isEmpty {
                    // A narrowed split window keeps its selected detail and back history.
                    column(current)
                } else if entry == .home {
                    home(selection: nil) { pushed = $0 }
                } else {
                    destination(entry, onOpen: { pushed = $0 }, onFinish: { dismiss() })
                }
            }
            .englishNavigationTitle(wide ? "Settings" : current.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $pushed) { next in
            SettingsView(
                sharedHealthDataService: sharedHealthDataService,
                canLoadHealthKitData: canLoadHealthKitData,
                hasFailedHealthKitAuthorization: hasFailedHealthKitAuthorization,
                entry: next
            )
        }
    }

    private func home(selection: SettingsHubRoute?, onOpen: @escaping (SettingsHubRoute) -> Void) -> some View {
        SettingsHome(selected: selection, onOpen: onOpen)
    }

    private func column(_ route: SettingsHubRoute) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if !columnHistory.isEmpty {
                    Button {
                        columnHistory.removeLast()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(Text("Go Back"))
                    .accessibilityIdentifier("settings-detail-back")
                }
                Text(verbatim: route.navigationTitle)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(minHeight: 48)
            destination(route, onOpen: { columnHistory.append($0) }, onFinish: {
                if columnHistory.count > 1 { columnHistory.removeLast() }
                else { columnHistory = [.gallery] }
            })
            .id(route)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func destination(
        _ route: SettingsHubRoute,
        onOpen: @escaping (SettingsHubRoute) -> Void,
        onFinish: @escaping () -> Void
    ) -> some View {
        switch route {
        case .gallery:
            ThemeGalleryView { onOpen(.preview($0)) }
        case .preview(let theme):
            SettingsThemePreview(theme: theme, onApply: onFinish)
        case .search:
            SettingsHubSearchView(query: $searchQuery, onOpen: onOpen)
        case .icons:
            AppIconPickerView()
        default:
            SettingsDetailView(
                route: route, sharedHealthDataService: sharedHealthDataService,
                canLoadHealthKitData: canLoadHealthKitData,
                hasFailedHealthKitAuthorization: hasFailedHealthKitAuthorization,
                onOpen: onOpen
            )
        }
    }
}

private struct SettingsHome: View {
    let selected: SettingsHubRoute?
    let onOpen: (SettingsHubRoute) -> Void

    @Environment(\.appTheme) private var theme
    @AppStorage(AppIconStyle.storageKey) private var icon: AppIconStyle = .defaultStyle
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                HStack {
                    Text("Appearance").font(.headline).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { onOpen(.search) } label: {
                        Image(systemName: "magnifyingglass")
                            .frame(minWidth: 44, minHeight: 44)
                            .background(theme.cardBackground, in: Circle())
                    }
                    .accessibilityLabel(Text("Search Settings"))
                    .accessibilityIdentifier("settings-hub-search")
                }
                SettingsCurrentThemeCard { onOpen(.gallery) }
                Button { onOpen(.icons) } label: {
                    HStack(spacing: DS.Spacing.md) {
                        Image(icon.previewAssetName(for: theme))
                            .resizable()
                            .frame(width: 32, height: 32)
                            .clipShape(.rect(cornerRadius: DS.Radius.sm))
                            .accessibilityHidden(true)
                        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())) {
                            Text("App Icon").font(.body.weight(.semibold))
                            if !typeSize.isAccessibilitySize { Spacer() }
                            Text(icon.displayName).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        chevron
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("settings-row-app-icon")
                Divider()
                VStack(spacing: 0) {
                    menuRow(.workout, id: "workout", title: "Workout Settings", subtitle: "Rest time and exercise defaults", symbol: "dumbbell")
                    Divider()
                    menuRow(.alerts, id: "alerts", title: "Notifications & Briefing", subtitle: "Health alerts and bedtime reminders", symbol: "bell")
                    Divider()
                    menuRow(.privacy, id: "privacy", title: "Data & Privacy", subtitle: "iCloud sync and permissions", symbol: "hand.raised")
                    Divider()
                    menuRow(.about, id: "about", title: "About", subtitle: "What's new and version", symbol: "info.circle")
                }
                .padding(.horizontal, DS.Spacing.md)
                .background(theme.cardBackground, in: .rect(cornerRadius: DS.Radius.lg))
                if SimulatorAdvancedMockDataModeStore.isSimulatorAvailable {
                    menuRow(.mockData, id: "mockData", title: "Mock Data", subtitle: nil, symbol: "shippingbox")
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(DS.Color.surfacePrimary)
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings-hub-home")
    }

    private var chevron: some View {
        Image(systemName: "chevron.forward").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private func menuRow(
        _ route: SettingsHubRoute, id: String, title: LocalizedStringKey,
        subtitle: LocalizedStringKey?, symbol: String
    ) -> some View {
        Button { onOpen(route) } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: symbol)
                    .foregroundStyle(theme.accentColor)
                    .frame(width: DS.Spacing.xxl)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title).font(.body.weight(.semibold))
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer()
                chevron
            }
            .frame(minHeight: 44)
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .background(selected == route ? theme.accentColor.opacity(0.10) : .clear)
        .accessibilityAddTraits(selected == route ? .isSelected : [])
        .accessibilityIdentifier("settings-hub-\(id)")
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
