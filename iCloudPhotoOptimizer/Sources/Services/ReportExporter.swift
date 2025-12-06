import Foundation
import AppKit
import PDFKit

/// Exports analysis reports in various formats
class ReportExporter {

    // MARK: - Types

    enum ExportFormat {
        case pdf
        case csv
        case json
        case html

        var fileExtension: String {
            switch self {
            case .pdf: return "pdf"
            case .csv: return "csv"
            case .json: return "json"
            case .html: return "html"
            }
        }

        var utType: String {
            switch self {
            case .pdf: return "com.adobe.pdf"
            case .csv: return "public.comma-separated-values-text"
            case .json: return "public.json"
            case .html: return "public.html"
            }
        }
    }

    struct ReportData {
        let generatedAt: Date
        let totalPhotos: Int
        let duplicateGroups: [DuplicateGroup]
        let similarGroups: [SimilarGroup]
        let qualityIssues: [QualityIssue]
        let sources: [PhotoSource]

        var totalDuplicates: Int {
            duplicateGroups.reduce(0) { $0 + $1.photos.count }
        }

        var totalSimilar: Int {
            similarGroups.reduce(0) { $0 + $1.photos.count }
        }

        var potentialSavings: Int64 {
            let dupSavings = duplicateGroups.reduce(0) { $0 + $1.potentialSavings }
            let simSavings = similarGroups.reduce(0) { $0 + $1.potentialSavings }
            let qualitySavings = qualityIssues.reduce(0) { $0 + $1.photo.fileSize }
            return dupSavings + simSavings + qualitySavings
        }
    }

    // MARK: - Public API

    /// Export report with save dialog
    func exportWithDialog(data: ReportData, format: ExportFormat) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.init(exportedAs: format.utType)]
        savePanel.nameFieldStringValue = "PhotoOptimizer_Report_\(dateString()).\(format.fileExtension)"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            export(data: data, format: format, to: url)
        }
    }

    /// Export report to specific URL
    func export(data: ReportData, format: ExportFormat, to url: URL) {
        switch format {
        case .pdf:
            exportToPDF(data: data, url: url)
        case .csv:
            exportToCSV(data: data, url: url)
        case .json:
            exportToJSON(data: data, url: url)
        case .html:
            exportToHTML(data: data, url: url)
        }
    }

    // MARK: - PDF Export

    private func exportToPDF(data: ReportData, url: URL) {
        let pdfDocument = PDFDocument()

        // Create content as attributed string
        let content = createPDFContent(data: data)

        // Create PDF page from content
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter size

        // Render to PDF data
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return
        }

        // Draw content
        var currentY: CGFloat = 750
        let margin: CGFloat = 50
        let pageWidth = pageRect.width - (margin * 2)

        context.beginPDFPage(nil)

        // Title
        drawText("iCloud Photo Optimizer Report", at: CGPoint(x: margin, y: currentY), fontSize: 24, bold: true, in: context)
        currentY -= 30

        // Generated date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        drawText("Generated: \(dateFormatter.string(from: data.generatedAt))", at: CGPoint(x: margin, y: currentY), fontSize: 12, in: context)
        currentY -= 40

        // Summary section
        drawText("Summary", at: CGPoint(x: margin, y: currentY), fontSize: 18, bold: true, in: context)
        currentY -= 25

        let summaryItems = [
            "Total Photos Scanned: \(data.totalPhotos)",
            "Duplicate Groups: \(data.duplicateGroups.count) (\(data.totalDuplicates) photos)",
            "Similar Photo Groups: \(data.similarGroups.count) (\(data.totalSimilar) photos)",
            "Quality Issues: \(data.qualityIssues.count)",
            "Potential Savings: \(formatBytes(data.potentialSavings))"
        ]

        for item in summaryItems {
            drawText("• \(item)", at: CGPoint(x: margin + 20, y: currentY), fontSize: 12, in: context)
            currentY -= 18
        }

        currentY -= 20

        // Duplicates section
        if !data.duplicateGroups.isEmpty {
            drawText("Duplicate Groups", at: CGPoint(x: margin, y: currentY), fontSize: 16, bold: true, in: context)
            currentY -= 20

            for (index, group) in data.duplicateGroups.prefix(20).enumerated() {
                let text = "\(index + 1). \(group.photos.first?.filename ?? "Unknown") - \(group.photos.count) copies (\(group.matchType.rawValue))"
                drawText(text, at: CGPoint(x: margin + 20, y: currentY), fontSize: 10, in: context)
                currentY -= 15

                if currentY < 100 {
                    context.endPDFPage()
                    context.beginPDFPage(nil)
                    currentY = 750
                }
            }

            if data.duplicateGroups.count > 20 {
                drawText("... and \(data.duplicateGroups.count - 20) more groups", at: CGPoint(x: margin + 20, y: currentY), fontSize: 10, in: context)
                currentY -= 15
            }
        }

        context.endPDFPage()
        context.closePDF()

        try? pdfData.write(to: url)
    }

    private func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, bold: Bool = false, in context: CGContext) {
        let font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        let string = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(string)

        context.textPosition = point
        CTLineDraw(line, context)
    }

    private func createPDFContent(data: ReportData) -> NSAttributedString {
        let content = NSMutableAttributedString()

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24)
        ]
        content.append(NSAttributedString(string: "iCloud Photo Optimizer Report\n\n", attributes: titleAttrs))

        return content
    }

    // MARK: - CSV Export

    private func exportToCSV(data: ReportData, url: URL) {
        var csv = "Category,Item,Details,Size,Potential Savings\n"

        // Duplicates
        for group in data.duplicateGroups {
            for (index, photo) in group.photos.enumerated() {
                let isKeep = index == group.recommendedKeepIndex
                csv += "Duplicate,\"\(photo.filename)\",\"\(group.matchType.rawValue) - \(isKeep ? "Keep" : "Delete")\",\(photo.fileSize),\(isKeep ? 0 : photo.fileSize)\n"
            }
        }

        // Similar
        for group in data.similarGroups {
            for (index, photo) in group.photos.enumerated() {
                let isKeep = group.recommendedKeepIndices.contains(index)
                csv += "Similar,\"\(photo.filename)\",\"Similarity: \(Int(group.similarityScore * 100))% - \(isKeep ? "Keep" : "Delete")\",\(photo.fileSize),\(isKeep ? 0 : photo.fileSize)\n"
            }
        }

        // Quality Issues
        for issue in data.qualityIssues {
            let issueTypes = issue.issues.map { $0.displayName }.joined(separator: ", ")
            csv += "Quality Issue,\"\(issue.photo.filename)\",\"\(issueTypes) - Score: \(issue.scoreString)\",\(issue.photo.fileSize),\(issue.photo.fileSize)\n"
        }

        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - JSON Export

    private func exportToJSON(data: ReportData, url: URL) {
        let jsonData: [String: Any] = [
            "generated_at": ISO8601DateFormatter().string(from: data.generatedAt),
            "summary": [
                "total_photos": data.totalPhotos,
                "duplicate_groups": data.duplicateGroups.count,
                "similar_groups": data.similarGroups.count,
                "quality_issues": data.qualityIssues.count,
                "potential_savings_bytes": data.potentialSavings
            ],
            "duplicates": data.duplicateGroups.map { group in
                [
                    "id": group.id,
                    "match_type": group.matchType.rawValue,
                    "photo_count": group.photos.count,
                    "potential_savings": group.potentialSavings,
                    "photos": group.photos.map { photo in
                        [
                            "id": photo.id,
                            "filename": photo.filename,
                            "size": photo.fileSize,
                            "resolution": photo.resolution
                        ]
                    }
                ]
            },
            "similar": data.similarGroups.map { group in
                [
                    "id": group.id,
                    "similarity_score": group.similarityScore,
                    "group_type": group.groupType.rawValue,
                    "photo_count": group.photos.count,
                    "potential_savings": group.potentialSavings
                ]
            },
            "quality_issues": data.qualityIssues.map { issue in
                [
                    "photo_id": issue.photo.id,
                    "filename": issue.photo.filename,
                    "score": issue.overallScore,
                    "issues": issue.issues.map { $0.displayName }
                ]
            }
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted) {
            try? jsonData.write(to: url)
        }
    }

    // MARK: - HTML Export

    private func exportToHTML(data: ReportData, url: URL) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>iCloud Photo Optimizer Report</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 40px; background: #f5f5f7; }
                .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                h1 { color: #1d1d1f; }
                h2 { color: #424245; border-bottom: 1px solid #d2d2d7; padding-bottom: 10px; }
                .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 30px 0; }
                .stat-card { background: #f5f5f7; padding: 20px; border-radius: 8px; text-align: center; }
                .stat-value { font-size: 36px; font-weight: bold; color: #0071e3; }
                .stat-label { color: #86868b; margin-top: 5px; }
                table { width: 100%; border-collapse: collapse; margin: 20px 0; }
                th, td { padding: 12px; text-align: left; border-bottom: 1px solid #d2d2d7; }
                th { background: #f5f5f7; font-weight: 600; }
                .badge { display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 12px; }
                .badge-red { background: #ffebee; color: #c62828; }
                .badge-orange { background: #fff3e0; color: #e65100; }
                .badge-yellow { background: #fffde7; color: #f57f17; }
                .badge-green { background: #e8f5e9; color: #2e7d32; }
                .savings { color: #34c759; font-weight: bold; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>📸 iCloud Photo Optimizer Report</h1>
                <p>Generated: \(dateFormatter.string(from: data.generatedAt))</p>

                <div class="summary">
                    <div class="stat-card">
                        <div class="stat-value">\(data.totalPhotos)</div>
                        <div class="stat-label">Photos Scanned</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">\(data.duplicateGroups.count)</div>
                        <div class="stat-label">Duplicate Groups</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">\(data.similarGroups.count)</div>
                        <div class="stat-label">Similar Groups</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">\(data.qualityIssues.count)</div>
                        <div class="stat-label">Quality Issues</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value savings">\(formatBytes(data.potentialSavings))</div>
                        <div class="stat-label">Potential Savings</div>
                    </div>
                </div>

                <h2>Duplicate Groups (\(data.duplicateGroups.count))</h2>
                <table>
                    <tr>
                        <th>File</th>
                        <th>Copies</th>
                        <th>Match Type</th>
                        <th>Potential Savings</th>
                    </tr>
                    \(data.duplicateGroups.prefix(50).map { group in
                        "<tr><td>\(group.photos.first?.filename ?? "Unknown")</td><td>\(group.photos.count)</td><td><span class=\"badge badge-red\">\(group.matchType.rawValue)</span></td><td class=\"savings\">\(formatBytes(group.potentialSavings))</td></tr>"
                    }.joined())
                </table>

                <h2>Similar Photo Groups (\(data.similarGroups.count))</h2>
                <table>
                    <tr>
                        <th>Group</th>
                        <th>Photos</th>
                        <th>Similarity</th>
                        <th>Potential Savings</th>
                    </tr>
                    \(data.similarGroups.prefix(50).map { group in
                        "<tr><td>\(group.displayTitle)</td><td>\(group.photos.count)</td><td><span class=\"badge badge-orange\">\(Int(group.similarityScore * 100))%</span></td><td class=\"savings\">\(formatBytes(group.potentialSavings))</td></tr>"
                    }.joined())
                </table>

                <h2>Quality Issues (\(data.qualityIssues.count))</h2>
                <table>
                    <tr>
                        <th>File</th>
                        <th>Issues</th>
                        <th>Score</th>
                        <th>Size</th>
                    </tr>
                    \(data.qualityIssues.prefix(50).map { issue in
                        let issueTypes = issue.issues.map { "<span class=\"badge badge-yellow\">\($0.displayName)</span>" }.joined(separator: " ")
                        return "<tr><td>\(issue.photo.filename)</td><td>\(issueTypes)</td><td>\(issue.scoreString)</td><td>\(formatBytes(issue.photo.fileSize))</td></tr>"
                    }.joined())
                </table>
            </div>
        </body>
        </html>
        """

        try? html.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: Date())
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - SwiftUI Export View

import SwiftUI

struct ExportReportSheet: View {
    let appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedFormat: ReportExporter.ExportFormat = .html
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Report")
                .font(.headline)

            // Format selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Select format:")
                    .foregroundColor(.secondary)

                Picker("Format", selection: $selectedFormat) {
                    Text("HTML (Interactive)").tag(ReportExporter.ExportFormat.html)
                    Text("PDF (Printable)").tag(ReportExporter.ExportFormat.pdf)
                    Text("CSV (Spreadsheet)").tag(ReportExporter.ExportFormat.csv)
                    Text("JSON (Data)").tag(ReportExporter.ExportFormat.json)
                }
                .pickerStyle(.radioGroup)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Preview of what will be exported
            VStack(alignment: .leading, spacing: 8) {
                Text("Report will include:")
                    .foregroundColor(.secondary)

                HStack {
                    Label("\(appState.duplicateGroups.count) duplicate groups", systemImage: "doc.on.doc")
                    Spacer()
                }

                HStack {
                    Label("\(appState.similarGroups.count) similar photo groups", systemImage: "photo.on.rectangle")
                    Spacer()
                }

                HStack {
                    Label("\(appState.qualityIssues.count) quality issues", systemImage: "exclamationmark.triangle")
                    Spacer()
                }
            }
            .font(.caption)

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Export") {
                    exportReport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
        }
        .padding(24)
        .frame(width: 400, height: 350)
    }

    private func exportReport() {
        isExporting = true

        let data = ReportExporter.ReportData(
            generatedAt: Date(),
            totalPhotos: appState.totalPhotosCount,
            duplicateGroups: appState.duplicateGroups,
            similarGroups: appState.similarGroups,
            qualityIssues: appState.qualityIssues,
            sources: appState.photoSources
        )

        let exporter = ReportExporter()
        exporter.exportWithDialog(data: data, format: selectedFormat)

        dismiss()
    }
}
