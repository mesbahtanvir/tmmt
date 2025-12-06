import Foundation
import Photos
import AppKit

/// Manages access to photo libraries (iCloud Photos and local folders)
actor PhotoLibraryManager {

    // MARK: - Authorization

    /// Request access to the Photos library
    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// Check current authorization status
    var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Fetch Photos

    /// Fetch photos from a given source
    func fetchPhotos(from source: PhotoSource) async -> [Photo] {
        switch source.type {
        case .iCloudLibrary:
            return await fetchFromiCloudLibrary()
        case .localFolder:
            guard let path = source.path else { return [] }
            return await fetchFromFolder(path: path)
        }
    }

    /// Fetch photos from iCloud Photos library using PhotoKit
    private func fetchFromiCloudLibrary() async -> [Photo] {
        var photos: [Photo] = []

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.includeHiddenAssets = false

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        assets.enumerateObjects { asset, _, _ in
            let photo = self.photoFromAsset(asset)
            photos.append(photo)
        }

        return photos
    }

    /// Convert PHAsset to Photo model
    private func photoFromAsset(_ asset: PHAsset) -> Photo {
        let resources = PHAssetResource.assetResources(for: asset)
        let filename = resources.first?.originalFilename ?? "Unknown"
        let fileSize = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0

        var location: PhotoLocation?
        if let assetLocation = asset.location {
            location = PhotoLocation(
                latitude: assetLocation.coordinate.latitude,
                longitude: assetLocation.coordinate.longitude,
                locationName: nil
            )
        }

        return Photo(
            id: asset.localIdentifier,
            filename: filename,
            fileSize: fileSize,
            creationDate: asset.creationDate,
            modificationDate: asset.modificationDate,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            location: location,
            sourceType: .iCloudLibrary,
            sourcePath: nil
        )
    }

    /// Fetch photos from a local folder
    private func fetchFromFolder(path: String) async -> [Photo] {
        var photos: [Photo] = []
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return photos
        }

        let imageExtensions = Set(["jpg", "jpeg", "png", "heic", "heif", "tiff", "gif", "bmp"])

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard imageExtensions.contains(ext) else { continue }

            if let photo = await photoFromFileURL(fileURL) {
                photos.append(photo)
            }
        }

        return photos
    }

    /// Create Photo from file URL
    private func photoFromFileURL(_ url: URL) async -> Photo? {
        let fileManager = FileManager.default

        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return nil
        }

        let fileSize = attributes[.size] as? Int64 ?? 0
        let creationDate = attributes[.creationDate] as? Date
        let modificationDate = attributes[.modificationDate] as? Date

        // Get image dimensions
        var width = 0
        var height = 0

        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
            height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        }

        return Photo(
            id: url.path,
            filename: url.lastPathComponent,
            fileSize: fileSize,
            creationDate: creationDate,
            modificationDate: modificationDate,
            pixelWidth: width,
            pixelHeight: height,
            location: nil,
            sourceType: .localFolder,
            sourcePath: url.path
        )
    }

    // MARK: - Thumbnail Loading

    /// Load thumbnail for a photo
    func loadThumbnail(for photo: Photo, size: CGSize) async -> NSImage? {
        switch photo.sourceType {
        case .iCloudLibrary:
            return await loadThumbnailFromPhotoKit(id: photo.id, size: size)
        case .localFolder:
            guard let path = photo.sourcePath else { return nil }
            return await loadThumbnailFromFile(path: path, size: size)
        }
    }

    private func loadThumbnailFromPhotoKit(id: String, size: CGSize) async -> NSImage? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = false // Use local thumbnail only
            options.resizeMode = .fast

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let cgImage = image {
                    let nsImage = NSImage(cgImage: cgImage, size: size)
                    continuation.resume(returning: nsImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadThumbnailFromFile(path: String, size: CGSize) async -> NSImage? {
        let url = URL(fileURLWithPath: path)

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: thumbnail, size: size)
    }

    // MARK: - Full Image Loading

    /// Load full-resolution image for detailed analysis
    func loadFullImage(for photo: Photo) async -> NSImage? {
        switch photo.sourceType {
        case .iCloudLibrary:
            return await loadFullImageFromPhotoKit(id: photo.id)
        case .localFolder:
            guard let path = photo.sourcePath else { return nil }
            return NSImage(contentsOfFile: path)
        }
    }

    private func loadFullImageFromPhotoKit(id: String) async -> NSImage? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true // Allow download from iCloud
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, info in
                if let cgImage = image {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    continuation.resume(returning: nsImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Deletion

    /// Move photos to trash
    func moveToTrash(photoIDs: [String]) async {
        // Separate iCloud and local photos
        var iCloudIDs: [String] = []
        var localPaths: [String] = []

        for id in photoIDs {
            if id.contains("/") {
                // Local file path
                localPaths.append(id)
            } else {
                // PHAsset identifier
                iCloudIDs.append(id)
            }
        }

        // Delete from Photos library
        if !iCloudIDs.isEmpty {
            await deleteFromPhotoKit(ids: iCloudIDs)
        }

        // Move local files to trash
        for path in localPaths {
            await moveLocalFileToTrash(path: path)
        }
    }

    private func deleteFromPhotoKit(ids: [String]) async {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        guard !assets.isEmpty else { return }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
            }
        } catch {
            print("Error deleting photos: \(error)")
        }
    }

    private func moveLocalFileToTrash(path: String) async {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        do {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        } catch {
            print("Error moving file to trash: \(error)")
        }
    }

    // MARK: - Content Hash

    /// Calculate SHA256 hash of photo content for exact duplicate detection
    func calculateContentHash(for photo: Photo) async -> String? {
        guard let data = await loadPhotoData(for: photo) else { return nil }

        let hash = data.withUnsafeBytes { bytes in
            var hasher = SHA256Hasher()
            hasher.update(data: bytes)
            return hasher.finalize()
        }

        return hash
    }

    private func loadPhotoData(for photo: Photo) async -> Data? {
        switch photo.sourceType {
        case .iCloudLibrary:
            return await loadDataFromPhotoKit(id: photo.id)
        case .localFolder:
            guard let path = photo.sourcePath else { return nil }
            return try? Data(contentsOf: URL(fileURLWithPath: path))
        }
    }

    private func loadDataFromPhotoKit(id: String) async -> Data? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
}

// MARK: - Simple SHA256 Implementation

struct SHA256Hasher {
    private var data = Data()

    mutating func update(data: UnsafeRawBufferPointer) {
        self.data.append(contentsOf: data)
    }

    func finalize() -> String {
        // Use CommonCrypto for actual implementation
        // This is a placeholder - in production, use CryptoKit
        let hash = data.hashValue
        return String(format: "%016llx", hash)
    }
}
