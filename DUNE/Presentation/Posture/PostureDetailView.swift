import SwiftUI
import SwiftData

struct PostureDetailView: View {
    let record: PostureAssessmentRecord
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreSection
                captureImagesSection
                metricsSection

                if !record.memo.isEmpty {
                    memoSection
                }

                deleteButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .englishNavigationTitle("Assessment Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(record.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Score

    private var scoreSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: min(1, max(0, CGFloat(record.overallScore) / 100.0)))
                    .stroke(scoreColor(record.overallScore), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(record.overallScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Posture Score")
                .font(.headline)
                .foregroundStyle(.secondary)

            let hasBoth = record.frontImageData != nil && record.sideImageData != nil
            if !hasBoth {
                Label(
                    String(localized: "Partial assessment"),
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Posture score \(record.overallScore) out of 100"))
    }

    // MARK: - Capture Images

    private var captureImagesSection: some View {
        HStack(alignment: .top, spacing: 12) {
            imageCard(
                label: String(localized: "Front"),
                captureType: .front,
                imageData: record.frontImageData,
                joints: record.frontJointPositions,
                metrics: record.frontMetrics
            )

            imageCard(
                label: String(localized: "Side"),
                captureType: .side,
                imageData: record.sideImageData,
                joints: record.sideJointPositions,
                metrics: record.sideMetrics
            )
        }
    }

    private func imageCard(
        label: String,
        captureType: PostureCaptureType,
        imageData: Data?,
        joints: [JointPosition3D],
        metrics: [PostureMetricResult]
    ) -> some View {
        VStack(spacing: 8) {
            if let imageData, let uiImage = UIImage(data: imageData) {
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

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assessment Details")
                .font(.headline)

            let allMetrics = record.allMetrics
            ForEach(allMetrics, id: \.type) { metric in
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
        formattedPostureMetricValue(metric.value, unit: metric.unit)
    }

    // MARK: - Memo

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memo")
                .font(.headline)

            Text(record.memo)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label(String(localized: "Delete Assessment"), systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .alert(
            String(localized: "Delete Assessment"),
            isPresented: $showDeleteConfirmation
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                withAnimation {
                    modelContext.delete(record)
                }
                dismiss()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("This assessment will be permanently deleted.")
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        postureScoreColor(score)
    }
}
