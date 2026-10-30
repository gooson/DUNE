import SwiftUI

/// Full-screen morning briefing sheet with staggered section animations.
struct MorningBriefingView: View {
    let data: MorningBriefingData
    @State private var viewModel = MorningBriefingViewModel()
    @State private var visibleSections: Set<Int> = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    MorningBriefingHero()
                        .accessibilityIdentifier("dashboard-morning-briefing-hero")
                    if let sections = viewModel.sections {
                        // Section 1: Recovery Summary
                        briefingSection(index: 0) {
                            BriefingSectionCard(
                                iconName: "heart.text.clipboard",
                                title: sections.recoveryTitle,
                                message: sections.recoveryMessage,
                                accentColor: conditionColor,
                                kind: .recovery
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
                                message: sections.weeklyMessage,
                                accentColor: DS.Color.desertBronze,
                                kind: .weekly
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
                .padding(.vertical, DS.Spacing.xl)
                .frame(maxWidth: .infinity)
            }
            .background { SheetWaveBackground() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                        .accessibilityIdentifier("dashboard-morning-briefing-dismiss")
                }
            }
        }
        .accessibilityIdentifier("dashboard-morning-briefing-screen")
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

    @ViewBuilder
    private func briefingSection<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(visibleSections.contains(index) ? 1 : 0)
            .offset(y: visibleSections.contains(index) ? 0 : 20)
    }
}

// MARK: - Morning scene

private struct MorningBriefingHero: View {
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
                    .frame(width: 154, height: 154)
                    .position(x: size.width * 0.76, y: size.height * 0.43)
                    .blur(radius: 18)
                Circle()
                    .fill(DS.Color.warmGlow.opacity(0.74))
                    .frame(width: 78, height: 78)
                    .position(x: size.width * 0.76, y: size.height * 0.43)
                MorningRidge(crest: 0.64)
                    .fill(DS.Color.desertBronze.opacity(DS.Opacity.overlay))
                MorningRidge(crest: 0.79)
                    .fill(DS.Color.warmGlow.opacity(DS.Opacity.strong))
            }
            .accessibilityHidden(true)

            Text("Good Morning")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(DS.Spacing.xxl)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("dashboard-morning-briefing-heading")
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 220 : 205)
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

private enum BriefingArtworkKind {
    case recovery, guide, weekly, weather
}

private struct BriefingSectionCard: View {
    let iconName: String
    let title: String
    let message: String
    let accentColor: Color
    let kind: BriefingArtworkKind
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if !dynamicTypeSize.isAccessibilitySize {
                    BriefingArtwork(iconName: iconName, accentColor: accentColor, kind: kind)
                        .frame(height: 80)
                        .accessibilityHidden(true)
                }

                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.sm))
                layout {
                    Image(systemName: iconName)
                        .font(dynamicTypeSize.isAccessibilitySize ? .system(size: 32) : .title2)
                        .foregroundStyle(accentColor)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("\(accessibilityID)-title")
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 0)
                    }
                }
            }
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
}

private struct BriefingArtwork: View {
    let iconName: String
    let accentColor: Color
    let kind: BriefingArtworkKind

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(LinearGradient(
                        colors: [accentColor.opacity(DS.Opacity.overlay), DS.Color.surfacePrimary.opacity(DS.Opacity.medium)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))

                artworkDetail(in: geometry.size)

                Image(systemName: iconName)
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(accentColor)
                    .position(x: geometry.size.width * 0.76, y: geometry.size.height * 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    @ViewBuilder
    private func artworkDetail(in size: CGSize) -> some View {
        switch kind {
        case .recovery:
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 38, weight: .ultraLight))
                .foregroundStyle(accentColor.opacity(0.72))
                .position(x: size.width * 0.23, y: size.height * 0.53)
        case .guide:
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.system(size: 38, weight: .ultraLight))
                .foregroundStyle(accentColor.opacity(0.72))
                .position(x: size.width * 0.23, y: size.height * 0.5)
        case .weekly:
            MorningRidge(crest: 0.61)
                .fill(accentColor.opacity(DS.Opacity.overlay))
                .frame(width: size.width * 0.44, height: size.height)
                .position(x: size.width * 0.22, y: size.height * 0.5)
        case .weather:
            Image(systemName: "cloud")
                .font(.system(size: 46, weight: .ultraLight))
                .foregroundStyle(accentColor.opacity(0.76))
                .position(x: size.width * 0.23, y: size.height * 0.5)
        }
    }
}
