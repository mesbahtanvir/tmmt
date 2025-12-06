import Foundation
import AppKit
import Combine

/// Manages thumbnail loading and caching with memory and disk cache
actor ThumbnailCacheManager {

    // MARK: - Singleton

    static let shared = ThumbnailCacheManager()

    // MARK: - Cache Configuration

    private struct CacheConfig {
        static let memoryCacheLimit = 100 // Max thumbnails in memory
        static let diskCacheSizeMB = 500  // Max disk cache size
        static let thumbnailQuality: CGFloat = 0.8
    }

    // MARK: - Properties

    private var memoryCache: [String: CacheEntry] = [:]
    private var accessOrder: [String] = []
    private let fileManager = FileManager.default

    private var diskCacheURL: URL {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cacheDir.appendingPathComponent("iCloudPhotoOptimizer/Thumbnails", isDirectory: true)
    }

    // MARK: - Types

    private struct CacheEntry {
        let image: NSImage
        let size: CGSize
        let timestamp: Date
    }

    enum ThumbnailSize: Int {
        case small = 80
        case medium = 150
        case large = 300
        case extraLarge = 600

        var cgSize: CGSize {
            CGSize(width: rawValue, height: rawValue)
        }
    }

    // MARK: - Initialization

    private init() {
        Task {
            await ensureDiskCacheExists()
        }
    }

    // MARK: - Public API

    /// Get thumbnail for a photo, loading from cache or generating if needed
    func thumbnail(for photo: Photo, size: ThumbnailSize) async -> NSImage? {
        let cacheKey = cacheKey(for: photo.id, size: size)

        // Check memory cache first
        if let cached = memoryCache[cacheKey] {
            updateAccessOrder(cacheKey)
            return cached.image
        }

        // Check disk cache
        if let diskImage = await loadFromDiskCache(key: cacheKey) {
            addToMemoryCache(key: cacheKey, image: diskImage, size: size.cgSize)
            return diskImage
        }

        // Load from source
        let photoLibraryManager = PhotoLibraryManager()
        guard let image = await photoLibraryManager.loadThumbnail(for: photo, size: size.cgSize) else {
            return nil
        }

        // Cache the result
        addToMemoryCache(key: cacheKey, image: image, size: size.cgSize)
        await saveToDiskCache(key: cacheKey, image: image)

        return image
    }

    /// Preload thumbnails for a batch of photos
    func preloadThumbnails(for photos: [Photo], size: ThumbnailSize) async {
        await withTaskGroup(of: Void.self) { group in
            for photo in photos.prefix(20) { // Limit concurrent loads
                group.addTask {
                    _ = await self.thumbnail(for: photo, size: size)
                }
            }
        }
    }

    /// Clear memory cache
    func clearMemoryCache() {
        memoryCache.removeAll()
        accessOrder.removeAll()
    }

    /// Clear all caches (memory and disk)
    func clearAllCaches() async {
        clearMemoryCache()
        try? fileManager.removeItem(at: diskCacheURL)
        await ensureDiskCacheExists()
    }

    /// Get current cache size
    func getCacheInfo() async -> (memoryCount: Int, diskSizeMB: Double) {
        let memoryCount = memoryCache.count

        var diskSize: Int64 = 0
        if let enumerator = fileManager.enumerator(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    diskSize += Int64(size)
                }
            }
        }

        return (memoryCount, Double(diskSize) / 1_000_000.0)
    }

    // MARK: - Private Methods

    private func cacheKey(for photoID: String, size: ThumbnailSize) -> String {
        let sanitizedID = photoID.replacingOccurrences(of: "/", with: "_")
        return "\(sanitizedID)_\(size.rawValue)"
    }

    private func addToMemoryCache(key: String, image: NSImage, size: CGSize) {
        // Evict if at capacity
        if memoryCache.count >= CacheConfig.memoryCacheLimit {
            evictOldestFromMemory()
        }

        memoryCache[key] = CacheEntry(image: image, size: size, timestamp: Date())
        updateAccessOrder(key)
    }

    private func updateAccessOrder(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func evictOldestFromMemory() {
        guard let oldest = accessOrder.first else { return }
        accessOrder.removeFirst()
        memoryCache.removeValue(forKey: oldest)
    }

    private func ensureDiskCacheExists() async {
        if !fileManager.fileExists(atPath: diskCacheURL.path) {
            try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
    }

    private func loadFromDiskCache(key: String) async -> NSImage? {
        let fileURL = diskCacheURL.appendingPathComponent("\(key).jpg")
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    private func saveToDiskCache(key: String, image: NSImage) async {
        let fileURL = diskCacheURL.appendingPathComponent("\(key).jpg")

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: CacheConfig.thumbnailQuality]) else {
            return
        }

        try? jpegData.write(to: fileURL)

        // Check disk cache size and prune if needed
        await pruneDiskCacheIfNeeded()
    }

    private func pruneDiskCacheIfNeeded() async {
        let (_, diskSizeMB) = await getCacheInfo()

        guard diskSizeMB > Double(CacheConfig.diskCacheSizeMB) else { return }

        // Get all cached files sorted by modification date
        guard let enumerator = fileManager.enumerator(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var files: [(url: URL, date: Date, size: Int64)] = []

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
               let date = values.contentModificationDate,
               let size = values.fileSize {
                files.append((fileURL, date, Int64(size)))
            }
        }

        // Sort by date (oldest first)
        files.sort { $0.date < $1.date }

        // Remove oldest files until under limit
        var currentSize = files.reduce(0) { $0 + $1.size }
        let targetSize = Int64(CacheConfig.diskCacheSizeMB * 800_000) // 80% of limit

        for file in files {
            guard currentSize > targetSize else { break }
            try? fileManager.removeItem(at: file.url)
            currentSize -= file.size
        }
    }
}

// MARK: - SwiftUI Async Image View

import SwiftUI

/// Async thumbnail image view with loading state
struct AsyncThumbnailImage: View {
    let photo: Photo
    let size: ThumbnailCacheManager.ThumbnailSize
    var contentMode: ContentMode = .fill

    @State private var image: NSImage?
    @State private var isLoading = true
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                ZStack {
                    Color.gray.opacity(0.1)
                    ProgressView()
                        .scaleEffect(0.7)
                }
            } else {
                ZStack {
                    Color.gray.opacity(0.1)
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(width: size.cgSize.width, height: size.cgSize.height)
        .clipped()
        .cornerRadius(8)
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            loadTask?.cancel()
        }
        .onChange(of: photo.id) { _, _ in
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        loadTask?.cancel()
        isLoading = true
        image = nil

        loadTask = Task {
            let thumbnail = await ThumbnailCacheManager.shared.thumbnail(for: photo, size: size)

            if !Task.isCancelled {
                await MainActor.run {
                    self.image = thumbnail
                    self.isLoading = false
                }
            }
        }
    }
}

/// Grid of async loading thumbnails
struct ThumbnailGrid: View {
    let photos: [Photo]
    let size: ThumbnailCacheManager.ThumbnailSize
    let columns: Int
    let spacing: CGFloat
    let onSelect: (Photo) -> Void

    init(
        photos: [Photo],
        size: ThumbnailCacheManager.ThumbnailSize = .medium,
        columns: Int = 4,
        spacing: CGFloat = 8,
        onSelect: @escaping (Photo) -> Void
    ) {
        self.photos = photos
        self.size = size
        self.columns = columns
        self.spacing = spacing
        self.onSelect = onSelect
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: spacing) {
                ForEach(photos) { photo in
                    AsyncThumbnailImage(photo: photo, size: size)
                        .onTapGesture {
                            onSelect(photo)
                        }
                }
            }
            .padding()
        }
        .task {
            // Preload visible thumbnails
            await ThumbnailCacheManager.shared.preloadThumbnails(for: photos, size: size)
        }
    }
}
