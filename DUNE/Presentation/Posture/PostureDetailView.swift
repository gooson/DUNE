import SwiftUI
import SwiftData

struct PostureDetailView: View {
    let record: PostureAssessmentRecord
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var zoomImage: ZoomableImageItem?

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                scoreSection
                captureImagesSection
                metricsSection

                if record.frontImageData != nil {
                    symmetryLink
                }

                if !record.memo.isEmpty {
                    memoSection
                }

                deleteButton
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .englishNavigationTitle("Assessment Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(record.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .background { DetailWaveBackground() }
        .environment(\.waveColor, DS.Color.body)
        .postureImageZoom($zoomImage)
    }

    // MARK: - Score

    private var scoreSection: some View {
        VStack(spacing: DS.Spacing.sm) {
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
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Posture score \(record.overallScore) out of 100"))
    }

    // MARK: - Capture Images

    private var captureImagesSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
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
        VStack(spacing: DS.Spacing.sm) {
            if let imageData, let uiImage = UIImage(data: imageData)?.postureOrientationCorrected {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
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
                RoundedRectangle(cornerRadius: DS.Radius.sm)
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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Assessment Details")
                .font(.headline)

            let allMetrics = record.allMetrics
            ForEach(allMetrics, id: \.type) { metric in
                metricRow(metric)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func metricRow(_ metric: PostureMetricResult) -> some View {
        HStack(spacing: DS.Spacing.md) {
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
        .padding(.vertical, DS.Spacing.xs)
    }

    private func metricValueText(_ metric: PostureMetricResult) -> String {
        formattedPostureMetricValue(metric.value, unit: metric.unit)
    }

    // MARK: - Symmetry Link

    private var symmetryLink: some View {
        NavigationLink(value: PostureSymmetryDestination(id: record.id)) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3)
                    .foregroundStyle(DS.Color.body)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Left-Right Comparison")
                        .font(.subheadline.weight(.medium))
                    Text("Detailed symmetry analysis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Memo

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Memo")
                .font(.headline)

            Text(record.memo)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
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
