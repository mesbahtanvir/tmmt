import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddSource = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                // Stats Cards
                statsCardsSection

                // Photo Sources
                sourcesSection

                // Issues Found
                issuesSection

                // Quick Actions
                quickActionsSection
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showingAddSource) {
            AddSourceSheet()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Photo Library Overview")
                    .font(.title)
                    .fontWeight(.bold)

                if appState.isScanning {
                    Text("Scanning in progress...")
                        .foregroundColor(.secondary)
                } else if appState.scanProgress.photosScanned > 0 {
                    Text("Last scan: \(appState.scanProgress.photosScanned) photos analyzed")
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: { appState.startScan() }) {
                Label("Scan Now", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.isScanning)
        }
    }

    // MARK: - Stats Cards Section

    private var statsCardsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Photos",
                value: "\(appState.totalPhotosCount)",
                subtitle: "In library",
                icon: "photo.on.rectangle.angled",
                color: .blue
            )

            StatCard(
                title: "Potential Savings",
                value: formatBytes(appState.potentialSavings),
                subtitle: "Can be freed",
                icon: "arrow.down.circle",
                color: .green
            )

            StatCard(
                title: "Issues Found",
                value: "\(appState.issuesSummary.totalCount)",
                subtitle: "Need review",
                icon: "exclamationmark.circle",
                color: .orange
            )
        }
    }

    // MARK: - Sources Section

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sources")
                    .font(.headline)

                Spacer()

                Button(action: { showingAddSource = true }) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }

            VStack(spacing: 8) {
                ForEach(appState.photoSources) { source in
                    SourceRow(source: source)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Issues Section

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Issues Found")
                .font(.headline)

            VStack(spacing: 1) {
                IssueRow(
                    title: "Exact Duplicates",
                    count: appState.issuesSummary.duplicatesCount,
                    size: appState.issuesSummary.duplicatesSize,
                    color: .red,
                    tab: .duplicates
                )

                IssueRow(
                    title: "Similar Photos",
                    count: appState.issuesSummary.similarCount,
                    size: appState.issuesSummary.similarSize,
                    color: .orange,
                    tab: .similar
                )

                IssueRow(
                    title: "Quality Issues",
                    count: appState.issuesSummary.qualityCount,
                    size: appState.issuesSummary.qualitySize,
                    color: .yellow,
                    tab: .quality
                )
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            HStack {
                Spacer()
                Text("Total potential savings: ")
                    .foregroundColor(.secondary)
                Text(formatBytes(appState.issuesSummary.totalSize))
                    .fontWeight(.semibold)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Auto-Select Duplicates",
                    description: "Select obvious exact duplicates",
                    icon: "doc.on.doc.fill",
                    action: { /* TODO */ }
                )

                QuickActionButton(
                    title: "Review All Issues",
                    description: "Go through all issues one by one",
                    icon: "list.bullet.rectangle",
                    action: { /* TODO */ }
                )

                QuickActionButton(
                    title: "Export Report",
                    description: "Generate a summary report",
                    icon: "doc.text",
                    action: { /* TODO */ }
                )
            }
        }
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold))

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SourceRow: View {
    let source: PhotoSource
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            Image(systemName: source.type.icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Toggle(isOn: Binding(
                get: { source.isEnabled },
                set: { _ in toggleSource() }
            )) {
                Text(source.name)
            }
            .toggleStyle(.checkbox)

            Spacer()

            Text("\(source.photoCount) photos")
                .foregroundColor(.secondary)

            Image(systemName: source.scanStatus.icon)
                .foregroundColor(source.scanStatus.color)
        }
    }

    private func toggleSource() {
        if let index = appState.photoSources.firstIndex(where: { $0.id == source.id }) {
            appState.photoSources[index].isEnabled.toggle()
        }
    }
}

struct IssueRow: View {
    let title: String
    let count: Int
    let size: Int64
    let color: Color
    let tab: AppTab
    @EnvironmentObject var appState: AppState

    var body: some View {
        Button(action: { appState.selectedTab = tab }) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text("\(count) \(title)")

                Spacer()

                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct QuickActionButton: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct AddSourceSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedPath: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Photo Source")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("Select a folder to scan:")
                    .foregroundColor(.secondary)

                HStack {
                    TextField("Folder path", text: $selectedPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        selectFolder()
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Add Source") {
                    addSource()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPath.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
        }
    }

    private func addSource() {
        let source = PhotoSource(
            id: UUID().uuidString,
            name: URL(fileURLWithPath: selectedPath).lastPathComponent,
            type: .localFolder,
            path: selectedPath,
            isEnabled: true
        )
        appState.addPhotoSource(source)
        dismiss()
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
