import SwiftUI

/// Full-screen photo comparison view with zoom and swipe
struct PhotoComparisonView: View {
    let photos: [Photo]
    @Binding var selectedIndex: Int
    let onKeep: (Int) -> Void
    let onDelete: (Int) -> Void
    let onClose: () -> Void

    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showMetadata = true
    @State private var comparisonMode: ComparisonMode = .sideBySide

    enum ComparisonMode: String, CaseIterable {
        case sideBySide = "Side by Side"
        case overlay = "Overlay"
        case swipe = "Swipe"
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Content based on mode
            switch comparisonMode {
            case .sideBySide:
                sideBySideView
            case .overlay:
                overlayView
            case .swipe:
                swipeView
            }

            // Controls overlay
            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { scale in
                    zoomScale = scale
                }
                .onEnded { _ in
                    withAnimation {
                        zoomScale = max(1.0, min(zoomScale, 5.0))
                    }
                }
        )
        .onTapGesture(count: 2) {
            withAnimation {
                if zoomScale > 1.0 {
                    zoomScale = 1.0
                    offset = .zero
                } else {
                    zoomScale = 2.0
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)

            Spacer()

            // Comparison mode picker
            Picker("Mode", selection: $comparisonMode) {
                ForEach(ComparisonMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            Spacer()

            Button(action: { showMetadata.toggle() }) {
                Image(systemName: showMetadata ? "info.circle.fill" : "info.circle")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 16) {
            // Thumbnail strip
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            AsyncThumbnailImage(photo: photo, size: .small)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(index == selectedIndex ? Color.white : Color.clear, lineWidth: 2)
                                )
                                .id(index)
                                .onTapGesture {
                                    withAnimation {
                                        selectedIndex = index
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: selectedIndex) { _, newValue in
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
            .frame(height: 70)

            // Action buttons
            HStack(spacing: 24) {
                // Previous
                Button(action: {
                    if selectedIndex > 0 {
                        withAnimation { selectedIndex -= 1 }
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.largeTitle)
                }
                .disabled(selectedIndex == 0)

                Spacer()

                // Delete
                Button(action: { onDelete(selectedIndex) }) {
                    VStack {
                        Image(systemName: "trash.fill")
                            .font(.title2)
                        Text("Delete")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                }

                // Keep
                Button(action: { onKeep(selectedIndex) }) {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                        Text("Keep")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }

                Spacer()

                // Next
                Button(action: {
                    if selectedIndex < photos.count - 1 {
                        withAnimation { selectedIndex += 1 }
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.largeTitle)
                }
                .disabled(selectedIndex >= photos.count - 1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 40)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Side by Side View

    private var sideBySideView: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    ZStack(alignment: .bottom) {
                        // Photo
                        ZoomablePhotoView(photo: photo, zoomScale: $zoomScale, offset: $offset)
                            .frame(width: geometry.size.width / CGFloat(min(photos.count, 3)) - 2)

                        // Metadata overlay
                        if showMetadata {
                            photoMetadataOverlay(photo: photo, index: index)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Overlay View

    @State private var overlayOpacity: Double = 0.5

    private var overlayView: some View {
        ZStack {
            if photos.count >= 2 {
                // Base photo
                ZoomablePhotoView(photo: photos[0], zoomScale: $zoomScale, offset: $offset)

                // Overlay photo with adjustable opacity
                ZoomablePhotoView(photo: photos[1], zoomScale: $zoomScale, offset: $offset)
                    .opacity(overlayOpacity)

                // Opacity slider
                VStack {
                    Spacer()

                    HStack {
                        Text("Photo 1")
                            .foregroundColor(.white)
                        Slider(value: $overlayOpacity, in: 0...1)
                            .frame(width: 200)
                        Text("Photo 2")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.bottom, 150)
                }
            }
        }
    }

    // MARK: - Swipe View

    @State private var swipePosition: CGFloat = 0.5

    private var swipeView: some View {
        GeometryReader { geometry in
            ZStack {
                if photos.count >= 2 {
                    // Right photo (full)
                    ZoomablePhotoView(photo: photos[1], zoomScale: $zoomScale, offset: $offset)

                    // Left photo (clipped)
                    ZoomablePhotoView(photo: photos[0], zoomScale: $zoomScale, offset: $offset)
                        .clipShape(
                            Rectangle()
                                .size(width: geometry.size.width * swipePosition, height: geometry.size.height)
                        )

                    // Swipe line
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .position(x: geometry.size.width * swipePosition, y: geometry.size.height / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    swipePosition = max(0, min(1, value.location.x / geometry.size.width))
                                }
                        )

                    // Drag handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .foregroundColor(.black)
                        )
                        .position(x: geometry.size.width * swipePosition, y: geometry.size.height / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    swipePosition = max(0, min(1, value.location.x / geometry.size.width))
                                }
                        )
                }
            }
        }
    }

    // MARK: - Metadata Overlay

    private func photoMetadataOverlay(photo: Photo, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Photo \(index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)

                if let score = photo.qualityScore {
                    Text("Score: \(Int(score))")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(scoreColor(score))
                        .cornerRadius(4)
                }
            }

            Text(photo.resolution)
                .font(.caption2)

            Text(photo.formattedFileSize)
                .font(.caption2)

            if let date = photo.creationDate {
                Text(date.mediumFormatted)
                    .font(.caption2)
            }
        }
        .foregroundColor(.white)
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        .padding(8)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}

// MARK: - Zoomable Photo View

struct ZoomablePhotoView: View {
    let photo: Photo
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize

    @State private var image: NSImage?
    @State private var isLoading = true

    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomScale)
                    .offset(offset)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if zoomScale > 1.0 {
                                    offset = value.translation
                                }
                            }
                    )
            } else if isLoading {
                ProgressView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        let manager = PhotoLibraryManager()
        image = await manager.loadFullImage(for: photo)
        isLoading = false
    }
}

// MARK: - Quick Compare Sheet

struct QuickCompareSheet: View {
    let photos: [Photo]
    let recommendedIndex: Int
    let onDecision: (Set<Int>) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var selectedToKeep: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Compare Photos")
                    .font(.headline)

                Spacer()

                Button("Done") {
                    onDecision(selectedToKeep)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Photos
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        ComparePhotoCard(
                            photo: photo,
                            index: index,
                            isRecommended: index == recommendedIndex,
                            isSelected: selectedToKeep.contains(index),
                            onToggle: { toggleSelection(index) }
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Summary
            HStack {
                Text("Keeping \(selectedToKeep.count) of \(photos.count) photos")
                    .foregroundColor(.secondary)

                Spacer()

                let savings = photos.enumerated()
                    .filter { !selectedToKeep.contains($0.offset) }
                    .reduce(0) { $0 + $1.element.fileSize }

                Text("Savings: \(ByteCountFormatter.string(fromByteCount: savings, countStyle: .file))")
                    .foregroundColor(.green)
            }
            .padding()
        }
        .frame(width: 700, height: 500)
        .onAppear {
            // Auto-select recommended
            selectedToKeep.insert(recommendedIndex)
        }
    }

    private func toggleSelection(_ index: Int) {
        if selectedToKeep.contains(index) {
            // Don't allow deselecting if it's the last one
            if selectedToKeep.count > 1 {
                selectedToKeep.remove(index)
            }
        } else {
            selectedToKeep.insert(index)
        }
    }
}

struct ComparePhotoCard: View {
    let photo: Photo
    let index: Int
    let isRecommended: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                AsyncThumbnailImage(photo: photo, size: .large)
                    .frame(width: 200, height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                    )

                if isRecommended {
                    Label("BEST", systemImage: "star.fill")
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

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(photo.resolution)
                    .font(.caption)

                Text(photo.formattedFileSize)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let score = photo.qualityScore {
                    HStack {
                        Text("Quality:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(score))")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }

            // Selection button
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    Text(isSelected ? "Keep" : "Delete")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(isSelected ? .green : .red)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
