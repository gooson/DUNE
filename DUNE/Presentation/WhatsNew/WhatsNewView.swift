import SwiftUI

enum WhatsNewPresentationMode: Equatable {
    case automatic
    case manual
}

struct WhatsNewView: View {
    let releases: [WhatsNewReleaseData]
    let mode: WhatsNewPresentationMode
    var onPresented: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    /// In automatic mode, show only the latest (first) release.
    private var visibleReleases: [WhatsNewReleaseData] {
        switch mode {
        case .automatic:
            releases.first.map { [$0] } ?? []
        case .manual:
            releases
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                ForEach(visibleReleases) { release in
                    releaseSection(release: release)
                }
            }
            .padding(.vertical, DS.Spacing.md)
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
        .onAppear(perform: onPresented)
        .toolbar {
            if mode == .automatic {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("whatsnew-close-button")
                }
            }
        }
        .accessibilityIdentifier("whatsnew-screen")
    }

    // MARK: - Release Section

    private func releaseSection(release: WhatsNewReleaseData) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            sectionHeader(release: release)

            VStack(spacing: DS.Spacing.md) {
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
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("whatsnew-row-\(feature.id)")
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    private func sectionHeader(release: WhatsNewReleaseData) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .center) {
                Text("Version")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text(verbatim: release.version)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Text(release.intro)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.lg)
        .textCase(nil)
    }
}

// MARK: - Feature Row

private struct WhatsNewFeatureRow: View {
    let feature: WhatsNewFeatureItem

    private var tintColor: Color {
        WhatsNewStyle.tintColor(for: feature.area)
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: feature.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    tintColor.gradient,
                    in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                WhatsNewBadge(title: feature.area.badgeTitle, tint: tintColor)

                Text(feature.title)
                    .font(DS.Typography.sectionTitle)

                Text(feature.summary)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .strokeBorder(.white.opacity(DS.Opacity.light))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Feature Detail

private struct WhatsNewFeatureDetailView: View {
    let release: WhatsNewReleaseData
    let feature: WhatsNewFeatureItem
    let mode: WhatsNewPresentationMode

    private var tintColor: Color {
        WhatsNewStyle.tintColor(for: feature.area)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    Image(systemName: feature.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            tintColor.gradient,
                            in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        WhatsNewBadge(title: feature.area.badgeTitle, tint: tintColor)

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

                heroArtwork

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
        .accessibilityIdentifier("whatsnew-detail-\(feature.id)")
    }

    @ViewBuilder
    private var heroArtwork: some View {
        if let assetName = feature.screenshotAsset, !assetName.isEmpty {
            screenshotHero(assetName: assetName)
        } else {
            symbolHero
        }
    }

    /// Real screenshot hero — shown when screenshotAsset is provided and non-empty.
    /// Note: Image(_:) returns empty view if asset is absent from catalog.
    private func screenshotHero(assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 400)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .strokeBorder(.white.opacity(0.12))
            )
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(feature.title)
            .accessibilityIdentifier("whatsnew-artwork-\(feature.id)-hero")
    }

    /// Fallback SF Symbol hero — used when no screenshot is available.
    private var symbolHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tintColor.opacity(0.95), tintColor.opacity(0.45), DS.Color.primaryText.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 180, height: 180)
                .offset(x: 110, y: -50)

            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 120, height: 120)
                .offset(x: -100, y: 60)

            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: feature.symbolName)
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white)

                Text(feature.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .strokeBorder(.white.opacity(0.12))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(feature.title)
        .accessibilityIdentifier("whatsnew-artwork-\(feature.id)-hero")
    }
}

// MARK: - Style & Badges

private enum WhatsNewStyle {
    static func tintColor(for area: WhatsNewArea) -> Color {
        switch area {
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

#Preview {
    NavigationStack {
        WhatsNewView(
            releases: WhatsNewManager.shared.orderedReleases(preferredVersion: "0.5.0"),
            mode: .manual
        )
    }
}
