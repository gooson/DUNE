import SwiftUI

struct PostureComparisonView: View {
    let older: PostureAssessmentRecord
    let newer: PostureAssessmentRecord
    let viewModel: PostureHistoryViewModel

    @State private var zoomImage: ZoomableImageItem?

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                scoreComparison
                imageComparison
                metricDeltas
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .englishNavigationTitle("Comparison")
        .navigationBarTitleDisplayMode(.inline)
        .background { DetailWaveBackground() }
        .environment(\.waveColor, DS.Color.body)
        .postureImageZoom($zoomImage)
    }

    // MARK: - Score Comparison

    private var scoreComparison: some View {
        HStack(spacing: DS.Spacing.lg) {
            scoreColumn(
                label: older.date.formatted(.dateTime.month(.abbreviated).day()),
                score: older.overallScore
            )

            VStack(spacing: DS.Spacing.xs) {
                let delta = newer.overallScore - older.overallScore
                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(delta >= 0 ? "+\(delta)" : "\(delta)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(delta >= 0 ? .green : .red)
            }

            scoreColumn(
                label: newer.date.formatted(.dateTime.month(.abbreviated).day()),
                score: newer.overallScore
            )
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func scoreColumn(label: String, score: Int) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: min(1, max(0, CGFloat(score) / 100.0)))
                    .stroke(
                        scoreColor(score),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(.title3.weight(.bold))
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                        captureType: .front
                    )
                    comparisonImage(
                        imageData: newer.frontImageData,
                        joints: newer.frontJointPositions,
                        metrics: newer.frontMetrics,
                        captureType: .front
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
                        captureType: .side
                    )
                    comparisonImage(
                        imageData: newer.sideImageData,
                        joints: newer.sideJointPositions,
                        metrics: newer.sideMetrics,
                        captureType: .side
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
        captureType: PostureCaptureType
    ) -> some View {
        Group {
            if let imageData, let rawImage = UIImage(data: imageData) {
                let needsCorrection = rawImage.needsPostureOrientationCorrection
                let uiImage = needsCorrection ? rawImage.postureOrientationCorrected : rawImage
                let displayJoints = needsCorrection ? postureOrientationCorrectedJoints(joints) : joints

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
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: delta.type.iconName)
                .font(.subheadline)
                .foregroundStyle(deltaColor(delta))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(delta.type.displayName)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: DS.Spacing.xs) {
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

            Spacer()

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
