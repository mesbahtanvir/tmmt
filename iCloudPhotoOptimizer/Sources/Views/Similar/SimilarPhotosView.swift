import SwiftUI

struct SimilarPhotosView: View {
    @EnvironmentObject var appState: AppState
    @State private var similarityThreshold: Double = 0.7
    @State private var selectedGroupID: String?

    var body: some View {
        VStack(spacing: 0) {
            // Threshold slider
            thresholdHeader

            Divider()

            // Content
            if filteredGroups.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(filteredGroups) { group in
                            SimilarGroupCard(
                                group: group,
                                isExpanded: selectedGroupID == group.id,
                                onToggleExpand: { toggleExpand(group) }
                            )
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Footer
            footerView
        }
    }

    // MARK: - Threshold Header

    private var thresholdHeader: some View {
        HStack(spacing: 16) {
            Text("Similar Photos")
                .font(.headline)

            Spacer()

            Text("Similarity Threshold:")
                .foregroundColor(.secondary)

            Slider(value: $similarityThreshold, in: 0.5...0.95)
                .frame(width: 200)

            Text("\(Int(similarityThreshold * 100))%")
                .frame(width: 40)

            Text("More")
                .font(.caption)
                .foregroundColor(.secondary)

            Image(systemName: "arrow.left.arrow.right")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Fewer groups")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Similar Photos Found")
                .font(.headline)

            Text("Try lowering the similarity threshold or run a new scan")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Text("Selected: \(appState.selectedPhotoIDs.count) photos")
                .foregroundColor(.secondary)

            Text("(\(formatBytes(selectedSize)))")
                .foregroundColor(.secondary)

            Spacer()

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

    private var filteredGroups: [SimilarGroup] {
        appState.similarGroups.filter { $0.similarityScore >= similarityThreshold }
    }

    private var selectedSize: Int64 {
        var size: Int64 = 0
        for group in appState.similarGroups {
            for photo in group.photos {
                if appState.selectedPhotoIDs.contains(photo.id) {
                    size += photo.fileSize
                }
            }
        }
        return size
    }

    // MARK: - Actions

    private func toggleExpand(_ group: SimilarGroup) {
        if selectedGroupID == group.id {
            selectedGroupID = nil
        } else {
            selectedGroupID = group.id
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Similar Group Card

struct SimilarGroupCard: View {
    let group: SimilarGroup
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggleExpand) {
                HStack {
                    Image(systemName: group.groupType.icon)
                        .foregroundColor(.orange)

                    VStack(alignment: .leading) {
                        Text(group.displayTitle)
                            .font(.headline)

                        Text("\(group.photos.count) similar photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(formatBytes(group.potentialSavings) + " potential savings")
                        .font(.caption)
                        .foregroundColor(.green)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            // Photos grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(group.photos.enumerated()), id: \.element.id) { index, photo in
                        SimilarPhotoThumbnail(
                            photo: photo,
                            qualityScore: photo.qualityScore ?? 50,
                            isBest: group.recommendedKeepIndices.contains(index),
                            isBlurry: (photo.blurScore ?? 100) < 50,
                            isSelected: appState.selectedPhotoIDs.contains(photo.id),
                            onToggle: { toggleSelection(photo) }
                        )
                    }
                }
                .padding()
            }

            // Quality scores
            if isExpanded {
                Divider()

                HStack(spacing: 4) {
                    Text("Quality Scores:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(group.photos, id: \.id) { photo in
                        Text("\(Int(photo.qualityScore ?? 50))")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(scoreColor(photo.qualityScore ?? 50))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Divider()

            // Action buttons
            HStack {
                Button("Keep Best Only") {
                    keepBestOnly()
                }

                Button("Keep Top 2") {
                    keepTop(2)
                }

                Button("Keep All") {
                    keepAll()
                }

                Button("Custom") {
                    // Already in custom mode via individual toggles
                }

                Spacer()
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func toggleSelection(_ photo: Photo) {
        if appState.selectedPhotoIDs.contains(photo.id) {
            appState.selectedPhotoIDs.remove(photo.id)
        } else {
            appState.selectedPhotoIDs.insert(photo.id)
        }
    }

    private func keepBestOnly() {
        for (index, photo) in group.photos.enumerated() {
            if group.recommendedKeepIndices.contains(index) {
                appState.selectedPhotoIDs.remove(photo.id)
            } else {
                appState.selectedPhotoIDs.insert(photo.id)
            }
        }
    }

    private func keepTop(_ count: Int) {
        let sorted = group.photos.enumerated()
            .sorted { ($0.element.qualityScore ?? 0) > ($1.element.qualityScore ?? 0) }

        for (i, (_, photo)) in sorted.enumerated() {
            if i < count {
                appState.selectedPhotoIDs.remove(photo.id)
            } else {
                appState.selectedPhotoIDs.insert(photo.id)
            }
        }
    }

    private func keepAll() {
        for photo in group.photos {
            appState.selectedPhotoIDs.remove(photo.id)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Similar Photo Thumbnail

struct SimilarPhotoThumbnail: View {
    let photo: Photo
    let qualityScore: Double
    let isBest: Bool
    let isBlurry: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Photo placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.gray)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isBest ? Color.green : (isSelected ? Color.red : Color.clear), lineWidth: 3)
                    )

                // Badges
                VStack(alignment: .leading, spacing: 4) {
                    if isBest {
                        Label("BEST", systemImage: "star.fill")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }

                    if isBlurry {
                        Label("blur", systemImage: "camera.metering.unknown")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                .padding(6)
            }

            // Selection toggle
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isSelected ? "trash.fill" : "checkmark.circle.fill")
                    Text(isSelected ? "Delete" : "Keep")
                }
                .font(.caption)
                .foregroundColor(isSelected ? .red : .green)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    SimilarPhotosView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
