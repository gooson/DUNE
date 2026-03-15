import UIKit

/// Generates a professional PDF report from a posture assessment record.
struct PostureReportGenerator {

    private enum Layout {
        static let pageWidth: CGFloat = 612   // US Letter
        static let pageHeight: CGFloat = 792
        static let margin: CGFloat = 50
        static let contentWidth: CGFloat = pageWidth - margin * 2
        static let lineSpacing: CGFloat = 6
    }

    private enum Fonts {
        static let title = UIFont.systemFont(ofSize: 24, weight: .bold)
        static let subtitle = UIFont.systemFont(ofSize: 14, weight: .regular)
        static let sectionTitle = UIFont.systemFont(ofSize: 16, weight: .semibold)
        static let body = UIFont.systemFont(ofSize: 12, weight: .regular)
        static let bodyBold = UIFont.systemFont(ofSize: 12, weight: .semibold)
        static let caption = UIFont.systemFont(ofSize: 10, weight: .regular)
        static let scoreNumber = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .bold)
    }

    func generatePDF(from record: PostureAssessmentRecord) -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: Layout.pageWidth, height: Layout.pageHeight)
        )

        return renderer.pdfData { context in
            context.beginPage()
            var y = Layout.margin

            // Title
            y = drawTitle(at: y, date: record.date, context: context)
            y += Layout.lineSpacing * 2

            // Score
            y = drawScoreSection(at: y, score: record.overallScore)
            y += Layout.lineSpacing * 2

            // Metrics
            let allMetrics = record.allMetrics
            if !allMetrics.isEmpty {
                y = drawMetricsSection(at: y, metrics: allMetrics, context: context)
            }

            // Memo
            if !record.memo.isEmpty {
                if y > Layout.pageHeight - 120 {
                    context.beginPage()
                    y = Layout.margin
                }
                y = drawMemoSection(at: y, memo: record.memo)
            }

            // Footer
            drawFooter(context: context)
        }
    }

    // MARK: - Drawing Helpers

    private func drawTitle(at y: CGFloat, date: Date, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var currentY = y

        let title = "Posture Assessment Report" as NSString
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.title,
            .foregroundColor: UIColor.label,
        ]
        title.draw(in: CGRect(x: Layout.margin, y: currentY, width: Layout.contentWidth, height: 30), withAttributes: titleAttrs)
        currentY += 32

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateString = dateFormatter.string(from: date) as NSString
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.subtitle,
            .foregroundColor: UIColor.secondaryLabel,
        ]
        dateString.draw(in: CGRect(x: Layout.margin, y: currentY, width: Layout.contentWidth, height: 20), withAttributes: dateAttrs)
        currentY += 22

        // Divider
        let dividerPath = UIBezierPath()
        dividerPath.move(to: CGPoint(x: Layout.margin, y: currentY))
        dividerPath.addLine(to: CGPoint(x: Layout.pageWidth - Layout.margin, y: currentY))
        UIColor.separator.setStroke()
        dividerPath.lineWidth = 0.5
        dividerPath.stroke()
        currentY += Layout.lineSpacing

        return currentY
    }

    private func drawScoreSection(at y: CGFloat, score: Int) -> CGFloat {
        var currentY = y

        let sectionTitle = "Overall Score" as NSString
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.sectionTitle,
            .foregroundColor: UIColor.label,
        ]
        sectionTitle.draw(in: CGRect(x: Layout.margin, y: currentY, width: Layout.contentWidth, height: 22), withAttributes: sectionAttrs)
        currentY += 26

        let scoreString = "\(score) / 100" as NSString
        let scoreAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.scoreNumber,
            .foregroundColor: scoreUIColor(score),
        ]
        scoreString.draw(in: CGRect(x: Layout.margin, y: currentY, width: Layout.contentWidth, height: 56), withAttributes: scoreAttrs)
        currentY += 58

        return currentY
    }

    private func drawMetricsSection(at y: CGFloat, metrics: [PostureMetricResult], context: UIGraphicsPDFRendererContext) -> CGFloat {
        var currentY = y

        let sectionTitle = "Assessment Details" as NSString
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.sectionTitle,
            .foregroundColor: UIColor.label,
        ]
        sectionTitle.draw(in: CGRect(x: Layout.margin, y: currentY, width: Layout.contentWidth, height: 22), withAttributes: sectionAttrs)
        currentY += 28

        // Table header
        currentY = drawMetricTableHeader(at: currentY)
        currentY += 2

        for metric in metrics {
            if currentY > Layout.pageHeight - 80 {
                drawFooter(context: context)
                context.beginPage()
                currentY = Layout.margin
                currentY = drawMetricTableHeader(at: currentY)
                currentY += 2
            }
            currentY = drawMetricRow(at: currentY, metric: metric)
        }

        return currentY
    }

    private func drawMetricTableHeader(at y: CGFloat) -> CGFloat {
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.bodyBold,
            .foregroundColor: UIColor.secondaryLabel,
        ]

        let col1: CGFloat = Layout.margin
        let col2: CGFloat = Layout.margin + Layout.contentWidth * 0.45
        let col3: CGFloat = Layout.margin + Layout.contentWidth * 0.65
        let col4: CGFloat = Layout.margin + Layout.contentWidth * 0.85

        ("Metric" as NSString).draw(in: CGRect(x: col1, y: y, width: 200, height: 16), withAttributes: headerAttrs)
        ("Value" as NSString).draw(in: CGRect(x: col2, y: y, width: 80, height: 16), withAttributes: headerAttrs)
        ("Status" as NSString).draw(in: CGRect(x: col3, y: y, width: 80, height: 16), withAttributes: headerAttrs)
        ("Confidence" as NSString).draw(in: CGRect(x: col4, y: y, width: 80, height: 16), withAttributes: headerAttrs)

        let dividerY = y + 18
        let path = UIBezierPath()
        path.move(to: CGPoint(x: Layout.margin, y: dividerY))
        path.addLine(to: CGPoint(x: Layout.pageWidth - Layout.margin, y: dividerY))
        UIColor.separator.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        return dividerY + 4
    }

    private func drawMetricRow(at y: CGFloat, metric: PostureMetricResult) -> CGFloat {
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.body,
            .foregroundColor: UIColor.label,
        ]

        let col1: CGFloat = Layout.margin
        let col2: CGFloat = Layout.margin + Layout.contentWidth * 0.45
        let col3: CGFloat = Layout.margin + Layout.contentWidth * 0.65
        let col4: CGFloat = Layout.margin + Layout.contentWidth * 0.85

        let name = metric.type.displayName as NSString
        name.draw(in: CGRect(x: col1, y: y, width: col2 - col1 - 8, height: 16), withAttributes: bodyAttrs)

        let value = formattedPostureMetricValue(metric.value, unit: metric.unit) as NSString
        value.draw(in: CGRect(x: col2, y: y, width: 80, height: 16), withAttributes: bodyAttrs)

        let statusAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.body,
            .foregroundColor: statusUIColor(metric.status),
        ]
        let status = metric.status.displayName as NSString
        status.draw(in: CGRect(x: col3, y: y, width: 80, height: 16), withAttributes: statusAttrs)

        let confidence = "\(Int(metric.confidence * 100))%" as NSString
        confidence.draw(in: CGRect(x: col4, y: y, width: 60, height: 16), withAttributes: bodyAttrs)

        return y + 22
    }

    private func drawMemoSection(at y: CGFloat, memo: String) -> CGFloat {
        var currentY = y + Layout.lineSpacing

        let sectionTitle = "Notes" as NSString
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.sectionTitle,
            .foregroundColor: UIColor.label,
        ]
        sectionTitle.draw(in: CGRect(x: Layout.margin, y: currentY, width: Layout.contentWidth, height: 22), withAttributes: sectionAttrs)
        currentY += 26

        let memoAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.body,
            .foregroundColor: UIColor.secondaryLabel,
        ]
        let memoString = memo as NSString
        let memoRect = memoString.boundingRect(
            with: CGSize(width: Layout.contentWidth, height: 200),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: memoAttrs,
            context: nil
        )
        memoString.draw(
            in: CGRect(x: Layout.margin, y: currentY, width: Layout.contentWidth, height: memoRect.height + 4),
            withAttributes: memoAttrs
        )
        currentY += memoRect.height + 8

        return currentY
    }

    private func drawFooter(context: UIGraphicsPDFRendererContext) {
        let footerY = Layout.pageHeight - 30
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.caption,
            .foregroundColor: UIColor.tertiaryLabel,
        ]
        let footer = "Generated by DUNE" as NSString
        footer.draw(in: CGRect(x: Layout.margin, y: footerY, width: Layout.contentWidth, height: 14), withAttributes: footerAttrs)
    }

    // MARK: - Color Helpers

    private func scoreUIColor(_ score: Int) -> UIColor {
        if score >= 80 { return .systemGreen }
        if score >= 60 { return .systemYellow }
        return .systemRed
    }

    private func statusUIColor(_ status: PostureStatus) -> UIColor {
        switch status {
        case .normal: .systemGreen
        case .caution: .systemYellow
        case .warning: .systemRed
        case .unmeasurable: .systemGray
        }
    }
}
