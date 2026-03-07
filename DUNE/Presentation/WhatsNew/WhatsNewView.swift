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
                        .accessibilityIdentifier("whatsnew-row-\(feature.id)")
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
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("whatsnew-close-button")
                }
            }
        }
        .accessibilityIdentifier("whatsnew-screen")
    }

    private func releaseHeader(release: WhatsNewReleaseData) -> some View {
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
    let feature: WhatsNewFeatureItem

    private var tintColor: Color {
        WhatsNewStyle.tintColor(for: feature.area)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    WhatsNewBadge(title: feature.area.badgeTitle, tint: tintColor)

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

            WhatsNewFeatureCard(feature: feature, style: .thumbnail)
                .frame(maxWidth: .infinity)
                .frame(height: 138)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .accessibilityHidden(true)
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
                WhatsNewFeatureCard(feature: feature, style: .hero)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
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
        .accessibilityIdentifier("whatsnew-detail-\(feature.id)")
    }
}

// MARK: - SF Symbol Feature Card

private struct WhatsNewFeatureCard: View {
    let feature: WhatsNewFeatureItem
    let style: CardStyle

    enum CardStyle {
        case thumbnail
        case hero

        var cornerRadius: CGFloat {
            switch self {
            case .hero: DS.Radius.xl
            case .thumbnail: DS.Radius.lg
            }
        }

        var primarySize: CGFloat {
            switch self {
            case .hero: 64
            case .thumbnail: 36
            }
        }

        var secondarySize: CGFloat {
            switch self {
            case .hero: 32
            case .thumbnail: 20
            }
        }

        var secondaryOffset: CGSize {
            switch self {
            case .hero: CGSize(width: 60, height: -40)
            case .thumbnail: CGSize(width: 36, height: -24)
            }
        }
    }

    private var areaGradient: LinearGradient {
        let tint = WhatsNewStyle.tintColor(for: feature.area)
        return LinearGradient(
            colors: [tint.opacity(0.42), DS.Color.desertDusk],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(areaGradient)

            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(DS.Opacity.border))

            ZStack {
                // Decorative secondary symbol
                if let secondary = WhatsNewStyle.secondarySymbol(for: feature.area) {
                    Image(systemName: secondary)
                        .font(.system(size: style.secondarySize, weight: .semibold))
                        .foregroundStyle(.white.opacity(DS.Opacity.overlay))
                        .offset(style.secondaryOffset)
                }

                // Primary symbol
                Image(systemName: feature.symbolName)
                    .font(.system(size: style.primarySize, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityIdentifier("whatsnew-card-\(feature.id)-\(style == .hero ? "hero" : "thumbnail")")
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

    static func secondarySymbol(for area: WhatsNewArea) -> String? {
        switch area {
        case .today:
            "sparkles"
        case .activity:
            "flame.fill"
        case .wellness:
            "heart.fill"
        case .life:
            "checklist.checked"
        case .watch:
            "applewatch.watchface"
        case .settings:
            "paintpalette.fill"
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
            releases: WhatsNewManager.shared.orderedReleases(preferredVersion: "0.2.0"),
            mode: .manual
        )
    }
}
