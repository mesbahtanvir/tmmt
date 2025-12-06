import SwiftUI

struct QualityIssuesView: View {
    @EnvironmentObject var appState: AppState
    @State private var filter = QualityIssueFilter()
    @State private var sortOrder: SortOrder = .scoreAscending

    enum SortOrder: String, CaseIterable {
        case scoreAscending = "Score (Low to High)"
        case scoreDescending = "Score (High to Low)"
        case sizeDescending = "Size (Largest)"
        case dateDescending = "Date (Newest)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            filterBar

            Divider()

            // Content
            if filteredIssues.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(filteredIssues) { issue in
                            QualityIssueCard(issue: issue)
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Warning banner
            warningBanner

            // Footer
            footerView
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)]
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quality Issues")
                    .font(.headline)

                Spacer()

                Picker("Sort by", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .frame(width: 180)
            }

            HStack(spacing: 16) {
                Text("Filter by issue type:")
                    .foregroundColor(.secondary)

                Toggle("Blurry", isOn: $filter.showBlurry)
                    .toggleStyle(.checkbox)

                Toggle("Dark", isOn: $filter.showDark)
                    .toggleStyle(.checkbox)

                Toggle("Overexposed", isOn: $filter.showOverexposed)
                    .toggleStyle(.checkbox)

                Toggle("Low Resolution", isOn: $filter.showLowResolution)
                    .toggleStyle(.checkbox)

                Spacer()

                Text("\(filteredIssues.count) photos")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("No Quality Issues Found")
                .font(.headline)

            Text("All your photos look great!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Warning Banner

    private var warningBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)

            Text("Review carefully - these photos may be intentionally styled")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.1))
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Text("Selected: \(selectedCount) photos")
                .foregroundColor(.secondary)

            Text("(\(formatBytes(selectedSize)))")
                .foregroundColor(.secondary)

            Spacer()

            Button("Select All Shown") {
                selectAllFiltered()
            }
            .buttonStyle(.bordered)

            Button(action: { appState.moveSelectedToTrash() }) {
                Label("Move Selected to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(appState.selectedPhotoIDs.isEmpty)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Computed

    private var filteredIssues: [QualityIssue] {
        var issues = appState.qualityIssues.filter { filter.matches($0) }

        switch sortOrder {
        case .scoreAscending:
            issues.sort { $0.overallScore < $1.overallScore }
        case .scoreDescending:
            issues.sort { $0.overallScore > $1.overallScore }
        case .sizeDescending:
            issues.sort { $0.photo.fileSize > $1.photo.fileSize }
        case .dateDescending:
            issues.sort { ($0.photo.creationDate ?? .distantPast) > ($1.photo.creationDate ?? .distantPast) }
        }

        return issues
    }

    private var selectedCount: Int {
        filteredIssues.filter { appState.selectedPhotoIDs.contains($0.photo.id) }.count
    }

    private var selectedSize: Int64 {
        filteredIssues
            .filter { appState.selectedPhotoIDs.contains($0.photo.id) }
            .reduce(0) { $0 + $1.photo.fileSize }
    }

    // MARK: - Actions

    private func selectAllFiltered() {
        for issue in filteredIssues {
            appState.selectedPhotoIDs.insert(issue.photo.id)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Quality Issue Card

struct QualityIssueCard: View {
    let issue: QualityIssue
    @EnvironmentObject var appState: AppState

    private var isSelected: Bool {
        appState.selectedPhotoIDs.contains(issue.photo.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Photo preview
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 140)
                    .overlay(
                        Image(systemName: issueIcon)
                            .font(.system(size: 32))
                            .foregroundColor(issueColor.opacity(0.6))
                    )

                // Issue badge
                if let primary = issue.primaryIssue {
                    Label(primary.displayName.uppercased(), systemImage: primary.icon)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(primary.color.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                // Score
                HStack {
                    Text("Score:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(issue.scoreString)
                        .font(.headline)
                        .foregroundColor(scoreColor)

                    Spacer()

                    Text(issue.photo.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Issues list
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(issue.issues, id: \.self) { issueType in
                        HStack(spacing: 4) {
                            Image(systemName: issueType.icon)
                                .font(.caption2)
                                .foregroundColor(issueType.color)

                            Text(issueType.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Selection toggle
                Button(action: toggleSelection) {
                    HStack {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        Text(isSelected ? "Selected for deletion" : "Select for deletion")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(isSelected ? .red : .secondary)
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
        )
    }

    private var issueIcon: String {
        issue.primaryIssue?.icon ?? "exclamationmark.triangle"
    }

    private var issueColor: Color {
        issue.primaryIssue?.color ?? .orange
    }

    private var scoreColor: Color {
        if issue.overallScore >= 60 { return .green }
        if issue.overallScore >= 30 { return .yellow }
        return .red
    }

    private func toggleSelection() {
        if isSelected {
            appState.selectedPhotoIDs.remove(issue.photo.id)
        } else {
            appState.selectedPhotoIDs.insert(issue.photo.id)
        }
    }
}

#Preview {
    QualityIssuesView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
