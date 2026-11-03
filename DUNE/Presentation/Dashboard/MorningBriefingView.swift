import SwiftUI

/// Full-screen morning briefing sheet with staggered section animations.
struct MorningBriefingView: View {
    let data: MorningBriefingData
    @State private var viewModel = MorningBriefingViewModel()
    @State private var visibleSections: Set<Int> = []
    @State private var currentPeriod = LocalDayPeriod(date: DashboardClock.now())
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    MorningBriefingHero(title: briefingTitle)
                        .accessibilityIdentifier("dashboard-morning-briefing-hero")
                    if let sections = viewModel.sections {
                        // Section 1: Recovery Summary
                        briefingSection(index: 0) {
                            BriefingSectionCard(
                                iconName: "heart.text.clipboard",
                                title: sections.recoveryTitle,
                                message: sections.recoverySupportingMessage,
                                accentColor: conditionColor,
                                kind: .recovery,
                                highlights: sections.recoveryHighlights
                            )
                        }

                        // Section 2: Today's Guide
                        briefingSection(index: 1) {
                            BriefingSectionCard(
                                iconName: "figure.run.circle",
                                title: sections.guideTitle,
                                message: sections.guideMessage,
                                accentColor: DS.Color.activity,
                                kind: .guide
                            )
                        }

                        // Section 3: Weekly Context
                        briefingSection(index: 2) {
                            BriefingSectionCard(
                                iconName: "chart.bar.fill",
                                title: sections.weeklyTitle,
                                message: sections.weeklySupportingMessage,
                                accentColor: DS.Color.desertBronze,
                                kind: .weekly,
                                highlights: sections.weeklyHighlights,
                                progress: sections.weeklyGoalProgress
                            )
                        }

                        // Section 4: Weather (conditional)
                        if let weatherTitle = sections.weatherTitle,
                           let weatherMessage = sections.weatherMessage {
                            briefingSection(index: 3) {
                                BriefingSectionCard(
                                    iconName: "cloud.sun.fill",
                                    title: weatherTitle,
                                    message: weatherMessage,
                                    accentColor: DS.Color.weatherCloudy,
                                    kind: .weather
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: DS.Layout.rootContentMaxWidth)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
            .background { SheetWaveBackground() }
            .navigationTitle(briefingTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                        .accessibilityIdentifier("dashboard-morning-briefing-dismiss")
                }
            }
        }
        .accessibilityIdentifier("dashboard-morning-briefing-screen")
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            currentPeriod = LocalDayPeriod(date: DashboardClock.now())
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { currentPeriod = LocalDayPeriod(date: DashboardClock.now()) }
        }
        .onDisappear {
            MorningBriefingViewModel.markBriefingShown()
        }
        .task {
            viewModel.loadSections(from: data)
            if reduceMotion {
                visibleSections = [0, 1, 2, 3]
            } else {
                for index in 0..<4 {
                    try? await Task.sleep(for: .milliseconds(150 * index))
                    guard !Task.isCancelled else { return }
                    guard scenePhase == .active else {
                        visibleSections = [0, 1, 2, 3]
                        return
                    }
                    withAnimation(DS.Animation.emphasize) {
                        _ = visibleSections.insert(index)
                    }
                }
            }
        }
    }

    private var conditionColor: Color {
        data.conditionStatus.color
    }

    private var briefingTitle: String {
        currentPeriod == .morning
            ? String(localized: "Good Morning")
            : String(localized: "Morning Briefing")
    }

    @ViewBuilder
    private func briefingSection<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(visibleSections.contains(index) ? 1 : 0)
            .offset(y: visibleSections.contains(index) ? 0 : 20)
    }
}

// MARK: - Morning scene

private struct MorningBriefingHero: View {
    let title: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(LinearGradient(
                    colors: [DS.Color.surfacePrimary, DS.Color.warmGlow.opacity(DS.Opacity.overlay), DS.Color.desertBronze.opacity(DS.Opacity.medium)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            GeometryReader { geometry in
                let size = geometry.size
                Circle()
                    .fill(DS.Color.warmGlow.opacity(DS.Opacity.overlay))
                    .frame(width: 128, height: 128)
                    .position(x: size.width * 0.76, y: size.height * 0.43)
                    .blur(radius: 18)
                Circle()
                    .fill(DS.Color.warmGlow.opacity(0.74))
                    .frame(width: 64, height: 64)
                    .position(x: size.width * 0.76, y: size.height * 0.43)
                MorningRidge(crest: 0.64)
                    .fill(DS.Color.desertBronze.opacity(DS.Opacity.overlay))
                MorningRidge(crest: 0.79)
                    .fill(DS.Color.warmGlow.opacity(DS.Opacity.strong))
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(DS.Spacing.lg)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("dashboard-morning-briefing-heading")
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 220 : 126)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .contain)
    }
}

private struct MorningRidge: Shape {
    let crest: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height * crest))
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.height * (crest - 0.1)),
                control1: CGPoint(x: rect.width * 0.28, y: rect.height * (crest - 0.28)),
                control2: CGPoint(x: rect.width * 0.64, y: rect.height * (crest + 0.12))
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// MARK: - Section Card

private enum BriefingSectionKind {
    case recovery, guide, weekly, weather
}

private struct BriefingSectionCard: View {
    let iconName: String
    let title: String
    let message: String?
    let accentColor: Color
    let kind: BriefingSectionKind
    var highlights: [BriefingTemplateEngine.Highlight] = []
    var progress: Double?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: iconName)
                        .font(.subheadline)
                        .foregroundStyle(accentColor)
                        .accessibilityHidden(true)
                    Text(categoryTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DS.Color.textSecondary)
                }

                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("\(accessibilityID)-title")

                if !highlights.isEmpty {
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.lg))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.lg))
                    layout {
                        ForEach(highlights) { highlight in
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text(highlight.title)
                                    .font(.subheadline)
                                    .foregroundStyle(DS.Color.textSecondary)
                                Text(highlight.value)
                                    .font(.title.bold())
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("\(accessibilityID)-\(highlight.id.rawValue)-value")
                        }
                    }
                }

                if let progress {
                    ProgressView(value: progress)
                        .tint(accentColor)
                        .accessibilityLabel(Text("Weekly Exercise Goal"))
                }

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("\(accessibilityID)-message")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.sm)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityID)
    }

    private var accessibilityID: String {
        switch kind {
        case .recovery: "dashboard-morning-briefing-recovery"
        case .guide: "dashboard-morning-briefing-guide"
        case .weekly: "dashboard-morning-briefing-weekly"
        case .weather: "dashboard-morning-briefing-weather"
        }
    }

    private var categoryTitle: LocalizedStringKey {
        switch kind {
        case .recovery: "Today's Condition"
        case .guide: "Today's Workout"
        case .weekly: "This Week"
        case .weather: "Weather"
        }
    }
}
