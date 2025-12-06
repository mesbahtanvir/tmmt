import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedGroup: DuplicateGroup?
    @State private var filterSource: String = "all"
    @State private var autoSelectLowerQuality = true

    var body: some View {
        HSplitView {
            // Left: Group List
            groupListView
                .frame(minWidth: 250, maxWidth: 350)

            // Right: Detail View
            groupDetailView
                .frame(minWidth: 400)
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("Source", selection: $filterSource) {
                    Text("All Sources").tag("all")
                    ForEach(appState.photoSources) { source in
                        Text(source.name).tag(source.id)
                    }
                }
                .frame(width: 150)

                Spacer()

                Text("\(appState.duplicateGroups.count) groups")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Group List

    private var groupListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Duplicate Groups")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // List
            if appState.duplicateGroups.isEmpty {
                emptyStateView
            } else {
                List(appState.duplicateGroups, selection: $selectedGroup) { group in
                    DuplicateGroupRow(group: group, isSelected: selectedGroup?.id == group.id)
                        .tag(group)
                }
                .listStyle(.plain)
            }

            Divider()

            // Footer
            footerView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Duplicates Found")
                .font(.headline)

            Text("Run a scan to detect duplicate photos")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Start Scan") {
                appState.startScan()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footerView: some View {
        VStack(spacing: 12) {
            Toggle("Auto-select lower quality duplicates", isOn: $autoSelectLowerQuality)
                .font(.caption)

            HStack {
                Text("Selected: \(selectedCount) photos")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("(\(formatBytes(selectedSize)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: moveSelectedToTrash) {
                Label("Move Selected to Trash", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(appState.selectedPhotoIDs.isEmpty)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Group Detail

    private var groupDetailView: some View {
        Group {
            if let group = selectedGroup {
                DuplicateGroupDetailView(group: group)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Select a group to view details")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Computed

    private var selectedCount: Int {
        appState.selectedPhotoIDs.count
    }

    private var selectedSize: Int64 {
        // Calculate size of selected photos
        var size: Int64 = 0
        for group in appState.duplicateGroups {
            for photo in group.photos {
                if appState.selectedPhotoIDs.contains(photo.id) {
                    size += photo.fileSize
                }
            }
        }
        return size
    }

    // MARK: - Actions

    private func moveSelectedToTrash() {
        appState.moveSelectedToTrash()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Duplicate Group Row

struct DuplicateGroupRow: View {
    let group: DuplicateGroup
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(group.photos.first?.filename ?? "Unknown")
                    .lineLimit(1)

                HStack {
                    Text("\(group.photos.count) photos")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(group.matchType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(formatBytes(group.potentialSavings))
                    .font(.caption)
                    .foregroundColor(.green)

                Text("save")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Duplicate Group Detail View

struct DuplicateGroupDetailView: View {
    let group: DuplicateGroup
    @EnvironmentObject var appState: AppState
    @State private var selectedPhotoIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(group.photos.first?.filename ?? "Duplicate Group")
                    .font(.headline)

                Spacer()

                Text(group.matchType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Photo comparison
            HStack(spacing: 24) {
                ForEach(Array(group.photos.enumerated()), id: \.element.id) { index, photo in
                    PhotoCompareCard(
                        photo: photo,
                        isRecommendedKeep: index == group.recommendedKeepIndex,
                        isSelected: appState.selectedPhotoIDs.contains(photo.id),
                        onToggleSelection: { toggleSelection(photo) }
                    )
                }
            }
            .padding()

            Divider()

            // Match info
            HStack {
                Image(systemName: group.matchType.icon)
                    .foregroundColor(.blue)

                Text(group.matchType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Recommendation: Keep original")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Spacer()

            // Action buttons
            HStack {
                Button("Keep Left") {
                    keepPhoto(at: 0)
                }

                Button("Keep Right") {
                    keepPhoto(at: group.photos.count - 1)
                }

                Button("Keep Both") {
                    keepAll()
                }

                Button("Skip") {
                    // Move to next group
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func toggleSelection(_ photo: Photo) {
        if appState.selectedPhotoIDs.contains(photo.id) {
            appState.selectedPhotoIDs.remove(photo.id)
        } else {
            appState.selectedPhotoIDs.insert(photo.id)
        }
    }

    private func keepPhoto(at index: Int) {
        for (i, photo) in group.photos.enumerated() {
            if i != index {
                appState.selectedPhotoIDs.insert(photo.id)
            } else {
                appState.selectedPhotoIDs.remove(photo.id)
            }
        }
    }

    private func keepAll() {
        for photo in group.photos {
            appState.selectedPhotoIDs.remove(photo.id)
        }
    }
}

// MARK: - Photo Compare Card

struct PhotoCompareCard: View {
    let photo: Photo
    let isRecommendedKeep: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Photo preview
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                    )

                if isRecommendedKeep {
                    Text("★ BEST")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(8)
                }
            }

            // Selection indicator
            HStack {
                Image(systemName: isSelected ? "trash.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(isSelected ? .red : .green)

                Text(isSelected ? "DELETE" : "KEEP")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .red : .green)
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                MetadataRow(label: "Size", value: photo.formattedFileSize)
                MetadataRow(label: "Resolution", value: photo.resolution)
                if let date = photo.creationDate {
                    MetadataRow(label: "Date", value: formatDate(date))
                }
                MetadataRow(label: "Location", value: photo.sourceType.rawValue)
            }
            .font(.caption)

            // Toggle button
            Button(action: onToggleSelection) {
                Text(isSelected ? "Keep This" : "Delete This")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
                )
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Text(value)
        }
    }
}

#Preview {
    DuplicatesView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
