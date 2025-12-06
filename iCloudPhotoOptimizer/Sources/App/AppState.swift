import SwiftUI
import Combine

/// Central app state management
@MainActor
class AppState: ObservableObject {
    // MARK: - Navigation
    @Published var selectedTab: AppTab = .dashboard

    // MARK: - Scan State
    @Published var isScanning: Bool = false
    @Published var isPaused: Bool = false
    @Published var scanProgress: ScanProgress = ScanProgress()
    @Published var hasSavedSession: Bool = false

    // MARK: - Photo Sources
    @Published var photoSources: [PhotoSource] = []

    // MARK: - Analysis Results
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var similarGroups: [SimilarGroup] = []
    @Published var qualityIssues: [QualityIssue] = []

    // MARK: - Selection State
    @Published var selectedPhotoIDs: Set<String> = []

    // MARK: - Settings
    @Published var settings: AppSettings = AppSettings()

    // MARK: - Services
    private let photoLibraryManager = PhotoLibraryManager()
    private let imageAnalyzer = ImageAnalyzer()
    private let persistenceManager = ScanPersistenceManager()

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadSavedSession()
        setupDefaultSources()
    }

    // MARK: - Computed Properties

    var totalPhotosScanned: Int {
        scanProgress.photosScanned
    }

    var totalPhotosCount: Int {
        scanProgress.totalPhotos
    }

    var potentialSavings: Int64 {
        let duplicateSavings = duplicateGroups.reduce(0) { $0 + $1.potentialSavings }
        let similarSavings = similarGroups.reduce(0) { $0 + $1.potentialSavings }
        let qualitySavings = qualityIssues.reduce(0) { $0 + $1.photo.fileSize }
        return duplicateSavings + similarSavings + qualitySavings
    }

    var issuesSummary: IssuesSummary {
        IssuesSummary(
            duplicatesCount: duplicateGroups.count,
            duplicatesSize: duplicateGroups.reduce(0) { $0 + $1.potentialSavings },
            similarCount: similarGroups.count,
            similarSize: similarGroups.reduce(0) { $0 + $1.potentialSavings },
            qualityCount: qualityIssues.count,
            qualitySize: qualityIssues.reduce(0) { $0 + $1.photo.fileSize }
        )
    }

    // MARK: - Actions

    func startScan() {
        isScanning = true
        isPaused = false
        scanProgress = ScanProgress()

        Task {
            await performScan()
        }
    }

    func pauseScan() {
        isPaused = true
        isScanning = false
        saveSession()
    }

    func resumeSession() {
        guard hasSavedSession else { return }
        isScanning = true
        isPaused = false

        Task {
            await performScan(resuming: true)
        }
    }

    func selectAll() {
        // Implementation depends on current tab context
    }

    func deselectAll() {
        selectedPhotoIDs.removeAll()
    }

    func moveSelectedToTrash() {
        Task {
            await photoLibraryManager.moveToTrash(photoIDs: Array(selectedPhotoIDs))
            selectedPhotoIDs.removeAll()
        }
    }

    func addPhotoSource(_ source: PhotoSource) {
        photoSources.append(source)
    }

    func removePhotoSource(_ source: PhotoSource) {
        photoSources.removeAll { $0.id == source.id }
    }

    // MARK: - Private Methods

    private func setupDefaultSources() {
        // Add iCloud Photos Library as default source
        let iCloudSource = PhotoSource(
            id: "icloud-photos",
            name: "iCloud Photos Library",
            type: .iCloudLibrary,
            path: nil,
            isEnabled: true
        )
        photoSources.append(iCloudSource)
    }

    private func loadSavedSession() {
        if let session = persistenceManager.loadSession() {
            scanProgress = session.progress
            duplicateGroups = session.duplicateGroups
            similarGroups = session.similarGroups
            qualityIssues = session.qualityIssues
            hasSavedSession = true
        }
    }

    private func saveSession() {
        let session = ScanSession(
            progress: scanProgress,
            duplicateGroups: duplicateGroups,
            similarGroups: similarGroups,
            qualityIssues: qualityIssues,
            timestamp: Date()
        )
        persistenceManager.saveSession(session)
    }

    private func performScan(resuming: Bool = false) async {
        let enabledSources = photoSources.filter { $0.isEnabled }

        for source in enabledSources {
            guard isScanning && !isPaused else { break }

            await scanSource(source, resuming: resuming)
        }

        isScanning = false
        saveSession()
    }

    private func scanSource(_ source: PhotoSource, resuming: Bool) async {
        // Fetch photos from source
        let photos = await photoLibraryManager.fetchPhotos(from: source)

        await MainActor.run {
            scanProgress.totalPhotos += photos.count
        }

        // Process photos in batches for efficiency
        let batchSize = 100
        for batch in photos.chunked(into: batchSize) {
            guard isScanning && !isPaused else { break }

            // Analyze batch
            let analysis = await imageAnalyzer.analyzeBatch(batch, settings: settings)

            await MainActor.run {
                // Merge results
                duplicateGroups.append(contentsOf: analysis.duplicates)
                similarGroups.append(contentsOf: analysis.similar)
                qualityIssues.append(contentsOf: analysis.qualityIssues)

                scanProgress.photosScanned += batch.count
                scanProgress.lastProcessedID = batch.last?.id
            }

            // Periodic save
            if scanProgress.photosScanned % 500 == 0 {
                saveSession()
            }
        }
    }
}

// MARK: - Supporting Types

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case duplicates = "Duplicates"
    case similar = "Similar"
    case quality = "Quality"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .duplicates: return "doc.on.doc"
        case .similar: return "photo.on.rectangle"
        case .quality: return "exclamationmark.triangle"
        case .settings: return "gearshape"
        }
    }
}

struct ScanProgress: Codable {
    var photosScanned: Int = 0
    var totalPhotos: Int = 0
    var lastProcessedID: String?
    var startTime: Date = Date()

    var percentComplete: Double {
        guard totalPhotos > 0 else { return 0 }
        return Double(photosScanned) / Double(totalPhotos)
    }
}

struct IssuesSummary {
    let duplicatesCount: Int
    let duplicatesSize: Int64
    let similarCount: Int
    let similarSize: Int64
    let qualityCount: Int
    let qualitySize: Int64

    var totalCount: Int {
        duplicatesCount + similarCount + qualityCount
    }

    var totalSize: Int64 {
        duplicatesSize + similarSize + qualitySize
    }
}

struct ScanSession: Codable {
    let progress: ScanProgress
    let duplicateGroups: [DuplicateGroup]
    let similarGroups: [SimilarGroup]
    let qualityIssues: [QualityIssue]
    let timestamp: Date
}

struct AppSettings: Codable {
    var similarityThreshold: Double = 0.7
    var detectBlurry: Bool = true
    var detectDark: Bool = true
    var detectOverexposed: Bool = true
    var detectLowResolution: Bool = false
    var blurThreshold: Double = 100.0
    var darknessThreshold: Double = 0.2
    var brightnessThreshold: Double = 0.9
    var minimumResolution: Int = 1024
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
