import SwiftUI

/// Full-screen morning briefing sheet with staggered section animations.
struct MorningBriefingView: View {
    let data: MorningBriefingData
    @State private var viewModel = MorningBriefingViewModel()
    @State private var visibleSections: Set<Int> = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    if let sections = viewModel.sections {
                        // Section 1: Recovery Summary
                        briefingSection(index: 0) {
                            BriefingSectionCard(
                                iconName: "heart.text.clipboard",
                                title: sections.recoveryTitle,
                                message: sections.recoveryMessage,
                                accentColor: conditionColor
                            )
                        }

                        // Section 2: Today's Guide
                        briefingSection(index: 1) {
                            BriefingSectionCard(
                                iconName: "figure.run.circle",
                                title: sections.guideTitle,
                                message: sections.guideMessage,
                                accentColor: DS.Color.activity
                            )
                        }

                        // Section 3: Weekly Context
                        briefingSection(index: 2) {
                            BriefingSectionCard(
                                iconName: "chart.bar.fill",
                                title: sections.weeklyTitle,
                                message: sections.weeklyMessage,
                                accentColor: DS.Color.desertBronze
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
                                    accentColor: DS.Color.weatherCloudy
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .background { SheetWaveBackground() }
            .navigationTitle(String(localized: "Good Morning"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
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

// MARK: - Section Card

private struct BriefingSectionCard: View {
    let iconName: String
    let title: String
    let message: String
    let accentColor: Color

    var body: some View {
        InlineCard {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
