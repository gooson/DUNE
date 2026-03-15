#if !os(visionOS)
import SwiftData
import SwiftUI

struct PostureResultView: View {
    @Bindable var viewModel: PostureAssessmentViewModel
    let dismiss: DismissAction
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animatedScore: Double = 0
    @State private var zoomImage: ZoomableImageItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreSection
                captureImagesSection
                metricsSection
                memoSection
                actionButtons
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .postureImageZoom($zoomImage)
    }

    // MARK: - Score

    private var scoreSection: some View {
        let score = viewModel.combinedAssessment.overallScore
        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: animatedScore)
                    .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int((animatedScore * 100).rounded()))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())

                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .task(id: score) {
                let target = CGFloat(score) / 100.0
                if reduceMotion {
                    animatedScore = target
                } else {
                    withAnimation(DS.Animation.slow) {
                        animatedScore = target
                    }
                }
            }

            Text("Posture Score")
                .font(.headline)
                .foregroundStyle(.secondary)

            if !viewModel.hasBothCaptures {
                Label(
                    String(localized: "Partial assessment — capture both views for full results"),
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.hasBothCaptures
            ? "Posture score \(score) out of 100"
            : "Posture score \(score) out of 100, partial assessment"))
    }

    private func scoreColor(_ score: Int) -> Color {
        postureScoreColor(score)
    }

    // MARK: - Capture Images

    private var captureImagesSection: some View {
        HStack(alignment: .top, spacing: 12) {
            captureImageCard(
                label: String(localized: "Front"),
                captureType: .front,
                imageData: viewModel.frontResult?.imageData,
                joints: viewModel.frontAssessment?.jointPositions ?? [],
                metrics: viewModel.frontAssessment?.metrics ?? []
            )

            captureImageCard(
                label: String(localized: "Side"),
                captureType: .side,
                imageData: viewModel.sideResult?.imageData,
                joints: viewModel.sideAssessment?.jointPositions ?? [],
                metrics: viewModel.sideAssessment?.metrics ?? []
            )
        }
    }

    private func captureImageCard(
        label: String,
        captureType: PostureCaptureType,
        imageData: Data?,
        joints: [JointPosition3D],
        metrics: [PostureMetricResult]
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                if let imageData, let uiImage = UIImage(data: imageData)?.postureOrientationCorrected {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            if !joints.isEmpty {
                                JointOverlayView(
                                    jointPositions: joints,
                                    imageSize: uiImage.size,
                                    metrics: metrics,
                                    captureType: captureType
                                )
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            zoomImage = ZoomableImageItem(
                                uiImage: uiImage,
                                joints: joints,
                                metrics: metrics,
                                captureType: captureType,
                                label: label
                            )
                        }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)

                                Text(captureType == .front
                                    ? "Capture front view for analysis"
                                    : "Capture side view for analysis")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                }
            }

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            // Per-capture metric summary
            if !metrics.isEmpty {
                captureMetricSummary(metrics)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(label) view capture"))
    }

    private func captureMetricSummary(_ metrics: [PostureMetricResult]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(metrics) { metric in
                HStack(spacing: 4) {
                    Circle()
                        .fill(metric.status.color)
                        .frame(width: 6, height: 6)

                    Text(metric.type.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(metricValueText(metric))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assessment Details")
                .font(.headline)

            let allMetrics = viewModel.combinedAssessment.allMetrics
            ForEach(allMetrics) { metric in
                metricRow(metric)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metricRow(_ metric: PostureMetricResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: metric.type.iconName)
                .font(.title3)
                .foregroundStyle(metric.status.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.type.displayName)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: DS.Spacing.sm) {
                    Text(metricValueText(metric))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary)

                    confidenceBadge(metric.confidence)
                }
            }

            Spacer()

            Label(metric.status.displayName, systemImage: metric.status.iconName)
                .font(.caption.weight(.medium))
                .foregroundStyle(metric.status.color)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(metric.type.displayName), \(metric.status.displayName), \(metricValueText(metric))"))
    }

    private func metricValueText(_ metric: PostureMetricResult) -> String {
        formattedPostureMetricValue(metric.value, unit: metric.unit)
    }

    // MARK: - Memo

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memo")
                .font(.headline)

            TextField(
                String(localized: "Add a note about this assessment..."),
                text: $viewModel.memo,
                axis: .vertical
            )
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if viewModel.frontAssessment != nil && viewModel.sideAssessment == nil {
                Button {
                    viewModel.proceedToSideCapture()
                } label: {
                    Label(String(localized: "Capture Side View"), systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Button {
                saveAssessment()
            } label: {
                Label(String(localized: "Save Assessment"), systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canSave || viewModel.isSaving)
            .accessibilityHint(Text("Saves the posture assessment to your history"))

            Button {
                viewModel.retakeCurrentCapture()
            } label: {
                Text("Retake")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if let error = viewModel.validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Save

    private func saveAssessment() {
        guard let record = viewModel.createValidatedRecord() else { return }
        defer { viewModel.didFinishSaving() }
        modelContext.insert(record)
        viewModel.resetAll()
        dismiss()
    }
}
#endif
