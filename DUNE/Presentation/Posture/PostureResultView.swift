#if !os(visionOS)
import SwiftData
import SwiftUI

struct PostureResultView: View {
    @Bindable var viewModel: PostureAssessmentViewModel
    let dismiss: DismissAction
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var scoreFontSize: CGFloat = 36
    @ScaledMetric(relativeTo: .caption) private var scoreRingSize: CGFloat = 120
    @ScaledMetric(relativeTo: .title3) private var metricSymbolSize: CGFloat = 20

    private static let lightStatusColors: [PostureStatus: Color] = [
        .normal: .green.mix(with: .black, by: 0.45),
        .caution: .yellow.mix(with: .black, by: 0.45),
        .warning: .red.mix(with: .black, by: 0.45),
        .unmeasurable: .gray.mix(with: .black, by: 0.45)
    ]

    private func statusColor(_ status: PostureStatus) -> Color {
        colorScheme == .light ? Self.lightStatusColors[status, default: status.color] : status.color
    }

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    @State private var animatedScore: Double = 0
    @State private var zoomImage: ZoomableImageItem?

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                scoreSection
                captureImagesSection
                metricsSection

                StandardCard {
                    CorrectiveExercisesSectionView(recommendations: viewModel.correctiveRecommendations)
                }

                memoSection
                actionButtons
            }
            .frame(maxWidth: 680)
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("posture-result-screen")
        .background { DetailWaveBackground() }
        .environment(\.waveColor, DS.Color.body)
        .postureImageZoom($zoomImage)
    }

    // MARK: - Score

    private var scoreSection: some View {
        let score = viewModel.combinedAssessment.overallScore
        return VStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .stroke(palette.track, lineWidth: 12)
                    .frame(width: min(scoreRingSize, 220), height: min(scoreRingSize, 220))

                Circle()
                    .trim(from: 0, to: animatedScore)
                    .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: min(scoreRingSize, 220), height: min(scoreRingSize, 220))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int((animatedScore * 100).rounded()))")
                        .font(.system(size: min(scoreFontSize, 72), weight: .bold, design: .rounded))
                        .contentTransition(.numericText())

                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(palette.muted)
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
                .foregroundStyle(palette.ink)

            if !viewModel.hasBothCaptures {
                Label(
                    String(localized: "Partial assessment — capture both views for full results"),
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(palette.heroHighlight)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("posture-result-partial")
            }
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(palette.ink)
        .padding(DS.Spacing.xl)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .strokeBorder(palette.border, lineWidth: 1)
        }
        .accessibilityIdentifier("posture-result-score")
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
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.lg))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.md))
        return layout {
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
                if let imageData,
                   let displayContext = postureImageDisplayContext(imageData: imageData, joints: joints) {
                    let uiImage = displayContext.uiImage
                    let displayJoints = displayContext.joints

                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                            zoomImage = ZoomableImageItem(
                                uiImage: uiImage,
                                joints: displayJoints,
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

                                Group {
                                    if captureType == .front {
                                        Text("Capture front view for analysis")
                                    } else {
                                        Text("Capture side view for analysis")
                                    }
                                }
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
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Assessment Details")
                    .font(.headline)

                let allMetrics = viewModel.combinedAssessment.allMetrics
                ForEach(allMetrics) { metric in
                    metricRow(metric)
                }
            }
        }
    }

    private func metricRow(_ metric: PostureMetricResult) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
        return layout {
            Image(systemName: metric.type.iconName)
                .font(.title3)
                .foregroundStyle(statusColor(metric.status))
                .frame(width: min(metricSymbolSize, 40) + DS.Spacing.md)

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

            if !dynamicTypeSize.isAccessibilitySize { Spacer() }

            Label(metric.status.displayName, systemImage: metric.status.iconName)
                .font(.caption.weight(.medium))
                .foregroundStyle(statusColor(metric.status))
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityIdentifier("posture-result-metric-\(metric.type.rawValue)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(metric.type.displayName), \(metric.status.displayName), \(metricValueText(metric))"))
    }

    private func metricValueText(_ metric: PostureMetricResult) -> String {
        formattedPostureMetricValue(metric.value, unit: metric.unit)
    }

    // MARK: - Memo

    private var memoSection: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Memo")
                    .font(.headline)

                TextField(
                    String(localized: "Add a note about this assessment..."),
                    text: $viewModel.memo,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("posture-result-memo-field")
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if viewModel.frontAssessment != nil && viewModel.sideAssessment == nil {
                Button {
                    viewModel.proceedToSideCapture()
                } label: {
                    Label(String(localized: "Capture Side View"), systemImage: "camera.fill")
                        .foregroundStyle(theme.prominentButtonForegroundColor(for: colorScheme))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("posture-result-capture-side")
            }

            Button {
                saveAssessment()
            } label: {
                Label(String(localized: "Save Assessment"), systemImage: "square.and.arrow.down")
                    .foregroundStyle(theme.prominentButtonForegroundColor(for: colorScheme))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canSave || viewModel.isSaving)
            .accessibilityIdentifier("posture-result-save")
            .accessibilityHint(Text("Saves the posture assessment to your history"))

            Button {
                viewModel.retakeCurrentCapture()
            } label: {
                Text("Retake")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("posture-result-retake")

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
