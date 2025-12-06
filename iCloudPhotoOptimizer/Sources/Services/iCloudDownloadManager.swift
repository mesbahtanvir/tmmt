import Foundation
import Photos
import Combine

/// Manages downloading photos from iCloud for full analysis
actor iCloudDownloadManager {

    // MARK: - Types

    enum DownloadState {
        case notStarted
        case downloading(progress: Double)
        case completed
        case failed(error: String)
        case cancelled
    }

    struct DownloadTask: Identifiable {
        let id: String
        let photoID: String
        var state: DownloadState
        var progress: Double
        let startTime: Date
        var requestID: PHImageRequestID?
    }

    struct DownloadResult {
        let photoID: String
        let success: Bool
        let image: NSImage?
        let data: Data?
        let error: String?
    }

    // MARK: - Properties

    private var activeTasks: [String: DownloadTask] = [:]
    private var downloadQueue: [String] = []
    private var isProcessingQueue = false
    private let maxConcurrentDownloads = 3

    private let imageManager = PHCachingImageManager()

    // Progress publisher
    private let progressSubject = PassthroughSubject<(String, Double), Never>()
    var progressPublisher: AnyPublisher<(String, Double), Never> {
        progressSubject.eraseToAnyPublisher()
    }

    // MARK: - Public API

    /// Download a single photo from iCloud
    func downloadPhoto(_ photo: Photo) async -> DownloadResult {
        guard photo.sourceType == .iCloudLibrary else {
            // Local file, no download needed
            if let path = photo.sourcePath,
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let image = NSImage(data: data) {
                return DownloadResult(photoID: photo.id, success: true, image: image, data: data, error: nil)
            }
            return DownloadResult(photoID: photo.id, success: false, image: nil, data: nil, error: "File not found")
        }

        return await downloadFromiCloud(photoID: photo.id)
    }

    /// Download multiple photos with progress tracking
    func downloadPhotos(_ photos: [Photo], progressHandler: @escaping (Int, Int) -> Void) async -> [DownloadResult] {
        var results: [DownloadResult] = []
        let total = photos.count

        for (index, photo) in photos.enumerated() {
            let result = await downloadPhoto(photo)
            results.append(result)
            progressHandler(index + 1, total)
        }

        return results
    }

    /// Check if a photo needs to be downloaded from iCloud
    func needsDownload(_ photo: Photo) async -> Bool {
        guard photo.sourceType == .iCloudLibrary else { return false }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photo.id], options: nil)
        guard let asset = fetchResult.firstObject else { return false }

        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else { return false }

        // Check if the full-size image is available locally
        return !PHAssetResourceManager.default().isDataAvailableLocally(for: resource)
    }

    /// Get download state for a photo
    func getDownloadState(for photoID: String) -> DownloadState {
        return activeTasks[photoID]?.state ?? .notStarted
    }

    /// Cancel a download
    func cancelDownload(for photoID: String) {
        if let task = activeTasks[photoID], let requestID = task.requestID {
            PHImageManager.default().cancelImageRequest(requestID)
            activeTasks[photoID]?.state = .cancelled
        }

        downloadQueue.removeAll { $0 == photoID }
    }

    /// Cancel all downloads
    func cancelAllDownloads() {
        for (_, task) in activeTasks {
            if let requestID = task.requestID {
                PHImageManager.default().cancelImageRequest(requestID)
            }
        }
        activeTasks.removeAll()
        downloadQueue.removeAll()
    }

    // MARK: - Private Methods

    private func downloadFromiCloud(photoID: String) async -> DownloadResult {
        // Create download task
        let task = DownloadTask(
            id: UUID().uuidString,
            photoID: photoID,
            state: .downloading(progress: 0),
            progress: 0,
            startTime: Date()
        )
        activeTasks[photoID] = task

        // Fetch asset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photoID], options: nil)
        guard let asset = fetchResult.firstObject else {
            activeTasks[photoID]?.state = .failed(error: "Asset not found")
            return DownloadResult(photoID: photoID, success: false, image: nil, data: nil, error: "Asset not found")
        }

        // Request full-size image
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.progressHandler = { [weak self] progress, _, _, _ in
                Task {
                    await self?.updateProgress(photoID: photoID, progress: progress)
                }
            }

            let requestID = PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { [weak self] data, _, _, info in
                Task {
                    if let error = info?[PHImageErrorKey] as? Error {
                        await self?.markFailed(photoID: photoID, error: error.localizedDescription)
                        continuation.resume(returning: DownloadResult(
                            photoID: photoID,
                            success: false,
                            image: nil,
                            data: nil,
                            error: error.localizedDescription
                        ))
                    } else if let data = data, let image = NSImage(data: data) {
                        await self?.markCompleted(photoID: photoID)
                        continuation.resume(returning: DownloadResult(
                            photoID: photoID,
                            success: true,
                            image: image,
                            data: data,
                            error: nil
                        ))
                    } else {
                        await self?.markFailed(photoID: photoID, error: "Failed to load image data")
                        continuation.resume(returning: DownloadResult(
                            photoID: photoID,
                            success: false,
                            image: nil,
                            data: nil,
                            error: "Failed to load image data"
                        ))
                    }
                }
            }

            Task {
                await self.setRequestID(photoID: photoID, requestID: requestID)
            }
        }
    }

    private func updateProgress(photoID: String, progress: Double) {
        activeTasks[photoID]?.progress = progress
        activeTasks[photoID]?.state = .downloading(progress: progress)
        progressSubject.send((photoID, progress))
    }

    private func markCompleted(photoID: String) {
        activeTasks[photoID]?.state = .completed
    }

    private func markFailed(photoID: String, error: String) {
        activeTasks[photoID]?.state = .failed(error: error)
    }

    private func setRequestID(photoID: String, requestID: PHImageRequestID) {
        activeTasks[photoID]?.requestID = requestID
    }
}

// MARK: - PHAssetResourceManager Extension

extension PHAssetResourceManager {
    func isDataAvailableLocally(for resource: PHAssetResource) -> Bool {
        // Check if the resource data is available locally
        var isLocal = false

        let semaphore = DispatchSemaphore(value: 0)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = false

        requestData(for: resource, options: options) { _ in
            isLocal = true
        } completionHandler: { _ in
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 0.5)
        return isLocal
    }
}

// MARK: - SwiftUI Progress View

import SwiftUI

struct iCloudDownloadProgressView: View {
    let photoID: String
    @State private var progress: Double = 0
    @State private var state: iCloudDownloadManager.DownloadState = .notStarted

    var body: some View {
        Group {
            switch state {
            case .notStarted:
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundColor(.blue)

            case .downloading(let progress):
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, lineWidth: 2)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 8))
                }
                .frame(width: 24, height: 24)

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)

            case .failed:
                Image(systemName: "exclamationmark.icloud.fill")
                    .foregroundColor(.red)

            case .cancelled:
                Image(systemName: "xmark.circle")
                    .foregroundColor(.gray)
            }
        }
    }
}

/// Badge overlay for photos that need iCloud download
struct iCloudStatusBadge: View {
    let photo: Photo
    @State private var needsDownload = false

    var body: some View {
        Group {
            if needsDownload {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.caption)
                    .padding(4)
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
        }
        .task {
            if photo.sourceType == .iCloudLibrary {
                let manager = iCloudDownloadManager()
                needsDownload = await manager.needsDownload(photo)
            }
        }
    }
}
