import SwiftUI
import UIKit

enum WhatsNewPresentationMode: Equatable {
    case automatic
    case manual
}

struct WhatsNewView: View {
    let releases: [WhatsNewRelease]
    let mode: WhatsNewPresentationMode
    var onPresented: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(releases) { release in
                Section {
                    ForEach(release.features) { feature in
                        NavigationLink {
                            WhatsNewFeatureDetailView(
                                release: release,
                                feature: feature,
                                mode: mode
                            )
                        } label: {
                            WhatsNewFeatureRow(feature: feature)
                        }
                        .accessibilityIdentifier("whatsnew-row-\(feature.rawValue)")
                        .listRowInsets(EdgeInsets(
                            top: DS.Spacing.sm,
                            leading: DS.Spacing.lg,
                            bottom: DS.Spacing.sm,
                            trailing: DS.Spacing.lg
                        ))
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    releaseHeader(release: release)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background {
            switch mode {
            case .automatic:
                SheetWaveBackground()
            case .manual:
                DetailWaveBackground()
            }
        }
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: onPresented)
        .toolbar {
            if mode == .automatic {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .accessibilityIdentifier("whatsnew-screen")
    }

    private func releaseHeader(release: WhatsNewRelease) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("What's New")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            HStack(alignment: .top, spacing: DS.Spacing.md) {
                WhatsNewVersionBadge(version: release.version)

                Text(release.intro)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.lg)
        .textCase(nil)
    }
}

private struct WhatsNewFeatureRow: View {
    let feature: WhatsNewFeature

    private var tintColor: Color {
        WhatsNewStyle.tintColor(for: feature)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.sm) {
                        WhatsNewBadge(title: feature.badgeTitle, tint: tintColor)

                        Image(systemName: feature.symbolName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tintColor)
                    }

                    Text(feature.title)
                        .font(DS.Typography.sectionTitle)

                    Text(feature.summary)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                        .lineLimit(3)
                }
            }

            WhatsNewArtwork(feature: feature, style: .thumbnail)
                .frame(maxWidth: .infinity)
                .frame(height: 138)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }
}

private struct WhatsNewFeatureDetailView: View {
    let release: WhatsNewRelease
    let feature: WhatsNewFeature
    let mode: WhatsNewPresentationMode

    private var tintColor: Color {
        WhatsNewStyle.tintColor(for: feature)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                WhatsNewArtwork(feature: feature, style: .hero)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            WhatsNewBadge(title: feature.badgeTitle, tint: tintColor)

                            Text(feature.title)
                                .font(.system(.title2, design: .rounded, weight: .bold))

                            Text(feature.summary)
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        WhatsNewVersionBadge(version: release.version)
                    }
                }

                StandardCard {
                    Text(release.intro)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DS.Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .background {
            switch mode {
            case .automatic:
                SheetWaveBackground()
            case .manual:
                DetailWaveBackground()
            }
        }
        .navigationTitle(feature.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("whatsnew-detail-\(feature.rawValue)")
    }
}

private enum WhatsNewArtworkStyle: String {
    case thumbnail
    case hero
}

private struct WhatsNewArtwork: View {
    let feature: WhatsNewFeature
    let style: WhatsNewArtworkStyle

    var body: some View {
        if let image = UIImage(named: feature.imageAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityIdentifier("whatsnew-artwork-\(feature.rawValue)-\(style.rawValue)")
        } else {
            WhatsNewFeatureArtwork(feature: feature)
                .accessibilityIdentifier("whatsnew-fallback-\(feature.rawValue)-\(style.rawValue)")
        }
    }
}

private enum WhatsNewStyle {
    static func tintColor(for feature: WhatsNewFeature) -> Color {
        switch feature.area {
        case .today:
            DS.Color.vitals
        case .activity:
            DS.Color.activity
        case .wellness:
            DS.Color.body
        case .life:
            DS.Color.tabLife
        case .watch:
            DS.Color.positive
        case .settings:
            DS.Color.desertBronze
        }
    }
}

private struct WhatsNewBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(verbatim: title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(tint.opacity(DS.Opacity.overlay), in: Capsule())
            .foregroundStyle(tint)
    }
}

private struct WhatsNewVersionBadge: View {
    let version: String

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text("Version")
                .font(.caption.weight(.semibold))
            Text(verbatim: version)
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct WhatsNewFeatureArtwork: View {
    let feature: WhatsNewFeature

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(backgroundGradient)

            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .strokeBorder(.white.opacity(0.12))

            switch feature {
            case .widgets:
                widgetsArtwork
            case .conditionScore:
                conditionArtwork
            case .weather:
                weatherArtwork
            case .sleepDebt:
                sleepDebtArtwork
            case .notifications:
                notificationsArtwork
            case .muscleMap:
                muscleMapArtwork
            case .trainingReadiness:
                trainingArtwork
            case .wellness:
                wellnessArtwork
            case .habits:
                habitsArtwork
            case .themes:
                themesArtwork
            case .watchQuickStart:
                watchArtwork
            }
        }
    }

    private var backgroundGradient: LinearGradient {
        switch feature.area {
        case .today:
            LinearGradient(colors: [DS.Color.vitals.opacity(0.38), DS.Color.desertDusk], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .activity:
            LinearGradient(colors: [DS.Color.activity.opacity(0.42), DS.Color.desertBronze.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .wellness:
            LinearGradient(colors: [DS.Color.body.opacity(0.4), DS.Color.weatherNight.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .life:
            LinearGradient(colors: [DS.Color.tabLife.opacity(0.42), DS.Color.desertDusk], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .watch:
            LinearGradient(colors: [DS.Color.positive.opacity(0.45), DS.Color.desertDusk], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .settings:
            LinearGradient(colors: [DS.Color.desertBronze.opacity(0.5), DS.Color.desertDusk], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var conditionArtwork: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                mockScreen(icon: "heart.text.square.fill", title: String(localized: "Today"), subtitle: "84")
                mockScreen(icon: "bell.badge.fill", title: String(localized: "Notifications"), subtitle: "3")
            }
            .padding(.horizontal, DS.Spacing.lg)

            pulseRow(primary: "sparkles", secondary: "cloud.sun.fill")
        }
    }

    private var widgetsArtwork: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                mockScreen(icon: "square.grid.2x2.fill", title: String(localized: "Widgets"), subtitle: "3")
                mockScreen(icon: "heart.text.square.fill", title: String(localized: "Condition Score"), subtitle: "84")
            }
            .padding(.horizontal, DS.Spacing.lg)

            pulseRow(primary: "sparkles.rectangle.stack.fill", secondary: "heart.fill")
        }
    }

    private var notificationsArtwork: some View {
        VStack(spacing: DS.Spacing.md) {
            mockScreen(icon: "bell.badge.fill", title: String(localized: "Notifications"), subtitle: "3")
                .padding(.horizontal, DS.Spacing.lg)

            HStack(spacing: DS.Spacing.sm) {
                unreadDot
                unreadDot
                unreadDot
            }
        }
    }

    private var weatherArtwork: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                mockScreen(icon: "cloud.sun.fill", title: String(localized: "Today"), subtitle: "22°")
                mockScreen(icon: "figure.walk", title: String(localized: "Outdoor"), subtitle: "84")
            }
            .padding(.horizontal, DS.Spacing.lg)

            pulseRow(primary: "sun.max.fill", secondary: "wind")
        }
    }

    private var sleepDebtArtwork: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                mockScreen(icon: "moon.zzz.fill", title: String(localized: "Sleep Debt"), subtitle: "2h 40m")
                mockScreen(icon: "bed.double.fill", title: String(localized: "Sleep"), subtitle: "6h 10m")
            }
            .padding(.horizontal, DS.Spacing.lg)

            pulseRow(primary: "moon.stars.fill", secondary: "bed.double.fill")
        }
    }

    private var muscleMapArtwork: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                mockScreen(icon: "figure.stand", title: String(localized: "Muscle Map"), subtitle: "3D")
                mockScreen(icon: "bolt.heart.fill", title: String(localized: "Recovery"), subtitle: "7d")
            }
            .padding(.horizontal, DS.Spacing.lg)

            pulseRow(primary: "figure.strengthtraining.traditional", secondary: "waveform.path.ecg")
        }
    }

    private var trainingArtwork: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                mockScreen(icon: "figure.strengthtraining.traditional", title: String(localized: "Activity"), subtitle: "7d")
                mockScreen(icon: "sparkles", title: String(localized: "Suggested Workout"), subtitle: "PR")
            }
            .padding(.horizontal, DS.Spacing.lg)

            pulseRow(primary: "flame.fill", secondary: "sparkles")
        }
    }

    private var wellnessArtwork: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                mockScreen(icon: "leaf.fill", title: String(localized: "Wellness"), subtitle: "82")
                mockScreen(icon: "heart.fill", title: String(localized: "Condition Score"), subtitle: "84")
            }
            .padding(.horizontal, DS.Spacing.lg)

            pulseRow(primary: "heart.fill", secondary: "figure.stand")
        }
    }

    private var habitsArtwork: some View {
        VStack(spacing: DS.Spacing.md) {
            mockScreen(icon: "checklist.checked", title: String(localized: "Life"), subtitle: "3/5")
                .padding(.horizontal, DS.Spacing.lg)

            VStack(spacing: DS.Spacing.sm) {
                checklistRow
                checklistRow
                checklistRow
            }
            .padding(.horizontal, DS.Spacing.xxl)
        }
    }

    private var themesArtwork: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.md) {
                mockScreen(icon: "paintpalette.fill", title: String(localized: "Appearance"), subtitle: "8")
                mockScreen(icon: "sparkles", title: String(localized: "Themes"), subtitle: "Live")
            }
            .padding(.horizontal, DS.Spacing.lg)

            HStack(spacing: DS.Spacing.md) {
                themeSwatch(.orange)
                themeSwatch(.blue)
                themeSwatch(.green)
                themeSwatch(.pink)
                themeSwatch(.cyan)
            }
        }
    }

    private var watchArtwork: some View {
        HStack(spacing: DS.Spacing.xl) {
            deviceCard(icon: "applewatch.watchface", title: "Watch")
            Image(systemName: "arrow.left.arrow.right")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white.opacity(0.75))
            deviceCard(icon: "iphone", title: "iPhone")
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    private func mockScreen(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.headline)
                Text(verbatim: title)
                    .font(.caption.weight(.semibold))
            }

            Spacer(minLength: 0)

            Text(verbatim: subtitle)
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.12))
        )
    }

    private func pulseRow(primary: String, secondary: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            circleIcon(primary, diameter: 48)
            circleIcon(secondary, diameter: 40)
        }
    }

    private func deviceCard(icon: String, title: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(.white.opacity(0.12))
                .frame(width: 84, height: 112)
                .overlay {
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: icon)
                            .font(.system(size: 30, weight: .semibold))
                        Text(verbatim: title)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(.white.opacity(0.12))
                )
        }
    }

    private var checklistRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(.white.opacity(0.85))
                .frame(height: 8)
            Spacer()
        }
    }

    private func circleIcon(_ symbol: String, diameter: CGFloat) -> some View {
        Circle()
            .fill(.white.opacity(0.14))
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: diameter * 0.34, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    private var unreadDot: some View {
        Circle()
            .fill(.white.opacity(0.9))
            .frame(width: 8, height: 8)
    }

    private func themeSwatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            }
    }
}

#Preview {
    NavigationStack {
        WhatsNewView(
            releases: WhatsNewManager.shared.orderedReleases(preferredVersion: "0.2.0"),
            mode: .manual
        )
    }
}
