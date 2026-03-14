import SwiftData
import SwiftUI

struct PostureResultView: View {
    @Bindable var viewModel: PostureAssessmentViewModel
    let dismiss: DismissAction
    @Environment(\.modelContext) private var modelContext

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
    }

    // MARK: - Score

    private var scoreSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.combinedAssessment.overallScore) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(viewModel.combinedAssessment.overallScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
    }

    private var scoreColor: Color {
        let score = viewModel.combinedAssessment.overallScore
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .red
    }

    // MARK: - Capture Images

    private var captureImagesSection: some View {
        HStack(spacing: 12) {
            captureImageCard(
                label: String(localized: "Front"),
                imageData: viewModel.frontResult?.imageData,
                joints: viewModel.frontAssessment?.jointPositions ?? []
            )

            captureImageCard(
                label: String(localized: "Side"),
                imageData: viewModel.sideResult?.imageData,
                joints: viewModel.sideAssessment?.jointPositions ?? []
            )
        }
    }

    private func captureImageCard(
        label: String,
        imageData: Data?,
        joints: [JointPosition3D]
    ) -> some View {
        VStack(spacing: 4) {
            ZStack {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            if !joints.isEmpty {
                                JointOverlayView(
                                    jointPositions: joints,
                                    imageSize: uiImage.size
                                )
                            }
                        }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                        }
                }
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

                Text(metricValueText(metric))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(metric.status.displayName, systemImage: metric.status.iconName)
                .font(.caption.weight(.medium))
                .foregroundStyle(metric.status.color)
        }
        .padding(.vertical, 4)
    }

    private func metricValueText(_ metric: PostureMetricResult) -> String {
        let unitSuffix: String
        switch metric.unit {
        case .degrees: unitSuffix = "°"
        case .centimeters: unitSuffix = " cm"
        }
        return String(format: "%.1f%@", metric.value, unitSuffix)
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
        modelContext.insert(record)
        viewModel.didFinishSaving()
        dismiss()
    }
}
