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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.xl) {
                ForEach(releases) { release in
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        releaseHeader(release: release)

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
            releases: WhatsNewManager.shared.orderedReleases(preferredVersion: "0.2.0"),
            mode: .manual
        )
    }
}
