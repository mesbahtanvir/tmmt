import SwiftUI

/// Reusable photo grid component with lazy loading
struct PhotoGridView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columns: [GridItem]
    let content: (Item) -> Content

    init(
        items: [Item],
        minColumnWidth: CGFloat = 150,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.columns = [GridItem(.adaptive(minimum: minColumnWidth), spacing: spacing)]
        self.content = content
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    content(item)
                }
            }
            .padding()
        }
    }
}

/// Photo thumbnail view with loading state
struct PhotoThumbnailView: View {
    let photo: Photo
    let size: CGSize
    @State private var image: NSImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else if isLoading {
                ProgressView()
                    .frame(width: size.width, height: size.height)
                    .background(Color.gray.opacity(0.1))
            } else {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(.gray)
                    .frame(width: size.width, height: size.height)
                    .background(Color.gray.opacity(0.1))
            }
        }
        .cornerRadius(8)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let manager = PhotoLibraryManager()
        image = await manager.loadThumbnail(for: photo, size: size)
        isLoading = false
    }
}

/// Confirmation dialog component
struct ConfirmationDialog: View {
    let title: String
    let message: String
    let items: [(String, Int, Int64)]  // (category, count, size)
    let destructiveAction: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @State private var showPreview = true

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "trash")
                    .font(.title)
                    .foregroundColor(.red)

                Text(title)
                    .font(.headline)
            }

            Divider()

            // Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Summary:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(items, id: \.0) { item in
                    HStack {
                        Text("• \(item.1) \(item.0)")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: item.2, countStyle: .file))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                HStack {
                    Text("Total space to free:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(ByteCountFormatter.string(
                        fromByteCount: items.reduce(0) { $0 + $1.2 },
                        countStyle: .file
                    ))
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                }
            }

            // Options
            Toggle("Show me a final review before deleting", isOn: $showPreview)
                .font(.caption)

            // Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Photos will remain in Trash for 30 days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(destructiveAction) {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

/// Undo toast notification
struct UndoToast: View {
    let message: String
    let countdown: Int
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)

            Text(message)

            Spacer()

            Button("Undo") {
                onUndo()
            }
            .buttonStyle(.bordered)

            // Countdown indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                Circle()
                    .trim(from: 0, to: CGFloat(countdown) / 10.0)
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))

                Text("\(countdown)")
                    .font(.caption2)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

/// Session resume banner
struct SessionResumeBanner: View {
    let sessionInfo: SessionInfo
    let onResume: () -> Void
    let onStartFresh: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading) {
                Text("Previous session found")
                    .font(.headline)

                Text("\(sessionInfo.formattedTimestamp), \(Int(sessionInfo.progress.percentComplete * 100))% complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Resume Scan") {
                onResume()
            }
            .buttonStyle(.borderedProminent)

            Button("Start Fresh") {
                onStartFresh()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Empty state view
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Confirmation Dialog") {
    ConfirmationDialog(
        title: "Move 245 photos to Trash?",
        message: "This action can be undone within 30 days.",
        items: [
            ("exact duplicates", 180, 1_200_000_000),
            ("lower quality versions", 42, 400_000_000),
            ("blurry photos", 23, 300_000_000)
        ],
        destructiveAction: "Move to Trash",
        onConfirm: {},
        onCancel: {}
    )
}
