import SwiftUI

struct PostureComparisonView: View {
    let older: PostureAssessmentRecord
    let newer: PostureAssessmentRecord
    let viewModel: PostureHistoryViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .title3) private var scoreRingSize: CGFloat = 88

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    @State private var zoomImage: ZoomableImageItem?

    var body: some View {
        AdaptivePaneView {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    scoreComparison
                    imageComparison
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, DS.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("posture-comparison-photos-scroll")
        } secondary: {
            ScrollView {
                metricDeltas
                    .frame(maxWidth: 680)
                    .padding(.horizontal, DS.Spacing.lg)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("posture-comparison-metrics-scroll")
        }
        .englishNavigationTitle("Comparison")
        .navigationBarTitleDisplayMode(.inline)
        .background { DetailWaveBackground() }
        .environment(\.waveColor, DS.Color.body)
        .postureImageZoom($zoomImage)
    }

    // MARK: - Score Comparison

    private var scoreComparison: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DS.Spacing.lg))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.lg))
        return layout {
            scoreColumn(
                label: older.date.formatted(.dateTime.month(.abbreviated).day()),
                score: older.overallScore
            )

            VStack(spacing: DS.Spacing.xs) {
                let delta = newer.overallScore - older.overallScore
                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.muted)

                Text(delta >= 0 ? "+\(delta)" : "\(delta)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(delta >= 0 ? palette.heroPositive : .red)
            }

            scoreColumn(
                label: newer.date.formatted(.dateTime.month(.abbreviated).day()),
                score: newer.overallScore
            )
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(palette.ink)
        .padding(DS.Spacing.xl)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .strokeBorder(palette.border, lineWidth: 1)
        }
        .accessibilityIdentifier("posture-comparison-score")
    }

    private func scoreColumn(label: String, score: Int) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(palette.track, lineWidth: 7)
                    .frame(width: min(scoreRingSize, 136), height: min(scoreRingSize, 136))

                Circle()
                    .trim(from: 0, to: min(1, max(0, CGFloat(score) / 100.0)))
                    .stroke(
                        scoreColor(score),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .frame(width: min(scoreRingSize, 136), height: min(scoreRingSize, 136))
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(.system(size: min(scoreRingSize * 0.34, 46), weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.muted)
        }
    }

    // MARK: - Image Comparison

    private var imageComparison: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Photo Comparison")
                .font(.headline)

            // Front views
            if older.frontImageData != nil || newer.frontImageData != nil {
                comparisonLabel(String(localized: "Front"))
                HStack(spacing: DS.Spacing.sm) {
                    comparisonImage(
                        imageData: older.frontImageData,
                        joints: older.frontJointPositions,
                        metrics: older.frontMetrics,
                        captureType: .front,
                        identifier: "posture-comparison-photo-front-older"
                    )
                    comparisonImage(
                        imageData: newer.frontImageData,
                        joints: newer.frontJointPositions,
                        metrics: newer.frontMetrics,
                        captureType: .front,
                        identifier: "posture-comparison-photo-front-newer"
                    )
                }
            }

            // Side views
            if older.sideImageData != nil || newer.sideImageData != nil {
                comparisonLabel(String(localized: "Side"))
                HStack(spacing: DS.Spacing.sm) {
                    comparisonImage(
                        imageData: older.sideImageData,
                        joints: older.sideJointPositions,
                        metrics: older.sideMetrics,
                        captureType: .side,
                        identifier: "posture-comparison-photo-side-older"
                    )
                    comparisonImage(
                        imageData: newer.sideImageData,
                        joints: newer.sideJointPositions,
                        metrics: newer.sideMetrics,
                        captureType: .side,
                        identifier: "posture-comparison-photo-side-newer"
                    )
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func comparisonLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private func comparisonImage(
        imageData: Data?,
        joints: [JointPosition3D],
        metrics: [PostureMetricResult],
        captureType: PostureCaptureType,
        identifier: String
    ) -> some View {
        Group {
            if let imageData,
               let displayContext = postureImageDisplayContext(imageData: imageData, joints: joints) {
                let uiImage = displayContext.uiImage
                let displayJoints = displayContext.joints

                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        if !displayJoints.isEmpty {
                            JointOverlayView(
                                jointPositions: displayJoints,
                                imageSize: uiImage.size,
                                metrics: metrics,
                                captureType: captureType
                            )
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        zoomImage = .make(
                            uiImage: uiImage,
                            joints: displayJoints,
                            metrics: metrics,
                            captureType: captureType
                        )
                    }
                    .accessibilityIdentifier(identifier)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }
        }
    }

    // MARK: - Metric Deltas

    private var metricDeltas: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Metric Changes")
                .font(.headline)

            let deltas = viewModel.comparisonDelta(older: older, newer: newer)
            ForEach(deltas) { delta in
                metricDeltaRow(delta)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func metricDeltaRow(_ delta: MetricDelta) -> some View {
        let rowLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
        let valuesLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.xs))
        return rowLayout {
            Image(systemName: delta.type.iconName)
                .font(.subheadline)
                .foregroundStyle(deltaColor(delta))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(delta.type.displayName)
                    .font(.subheadline.weight(.medium))

                valuesLayout {
                    if let oldVal = delta.oldValue {
                        Text(formattedPostureMetricValue(oldVal, unit: delta.unit))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if let newVal = delta.newValue {
                        Text(formattedPostureMetricValue(newVal, unit: delta.unit))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            if let scoreDelta = delta.scoreDelta {
                Text(scoreDelta >= 0 ? "+\(scoreDelta)" : "\(scoreDelta)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(deltaColor(delta))
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    // MARK: - Helpers

    private func deltaColor(_ delta: MetricDelta) -> Color {
        guard let improved = delta.isImproved else { return .secondary }
        return improved ? .green : .red
    }

    private func scoreColor(_ score: Int) -> Color {
        postureScoreColor(score)
    }
}
