import SwiftUI
import UIKit

enum WhatsNewPresentationMode: Equatable {
    case automatic
    case manual
}

struct WhatsNewView: View {
    let releases: [WhatsNewRelease]
    let mode: WhatsNewPresentationMode
    let onOpenDestination: (WhatsNewDestination) -> Void

    @Environment(\.dismiss) private var dismiss

    private var currentRelease: WhatsNewRelease? { releases.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                if let currentRelease {
                    heroCard(release: currentRelease)

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("Highlights")
                            .font(DS.Typography.sectionTitle)

                        ForEach(currentRelease.features) { feature in
                            highlightCard(feature: feature)
                        }
                    }
                }

                if releases.count > 1 {
                    archiveSection
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
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
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

    private func heroCard(release: WhatsNewRelease) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("What's New")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))

                        Text(release.intro)
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    versionBadge(version: release.version)
                }
            }
        }
    }

    private func highlightCard(feature: WhatsNewFeature) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                artwork(for: feature)
                    .frame(height: 188)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))

                HStack(spacing: DS.Spacing.sm) {
                    badge(title: feature.badgeTitle, tint: tintColor(for: feature))

                    Spacer()

                    Image(systemName: feature.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tintColor(for: feature))
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(feature.title)
                        .font(DS.Typography.sectionTitle)

                    Text(feature.summary)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let destination = feature.destination {
                    Button {
                        openDestination(destination)
                    } label: {
                        Label("Open Feature", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("whatsnew-open-\(feature.rawValue)")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(tintColor(for: feature))
                }
            }
        }
        .accessibilityIdentifier("whatsnew-card-\(feature.rawValue)")
    }

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(Array(releases.dropFirst())) { release in
                StandardCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        versionBadge(version: release.version)

                        Text(release.intro)
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)

                        Text(release.features.map(\.title).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(DS.Color.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func artwork(for feature: WhatsNewFeature) -> some View {
        if let image = UIImage(named: feature.imageAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            WhatsNewFeatureArtwork(feature: feature)
        }
    }

    private func tintColor(for feature: WhatsNewFeature) -> Color {
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
        }
    }

    private func badge(title: String, tint: Color) -> some View {
        Text(verbatim: title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(tint.opacity(DS.Opacity.overlay), in: Capsule())
            .foregroundStyle(tint)
    }

    private func versionBadge(version: String) -> some View {
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

    private func openDestination(_ destination: WhatsNewDestination) {
        switch mode {
        case .automatic:
            onOpenDestination(destination)
        case .manual:
            dismiss()
            Task { @MainActor in
                onOpenDestination(destination)
            }
        }
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
            case .conditionScore:
                conditionArtwork
            case .notifications:
                notificationsArtwork
            case .trainingReadiness:
                trainingArtwork
            case .wellness:
                wellnessArtwork
            case .habits:
                habitsArtwork
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
}

#Preview {
    NavigationStack {
        WhatsNewView(
            releases: WhatsNewManager.shared.orderedReleases(preferredVersion: "0.2.0"),
            mode: .manual,
            onOpenDestination: { _ in }
        )
    }
}
