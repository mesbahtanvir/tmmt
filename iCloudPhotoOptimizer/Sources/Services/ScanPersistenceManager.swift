import Foundation

/// Manages persistence of scan sessions and analysis cache
class ScanPersistenceManager {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var appSupportDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("iCloudPhotoOptimizer", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: appSupport.path) {
            try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }

        return appSupport
    }

    private var sessionFile: URL {
        appSupportDirectory.appendingPathComponent("session.json")
    }

    private var cacheDirectory: URL {
        appSupportDirectory.appendingPathComponent("cache", isDirectory: true)
    }

    private var settingsFile: URL {
        appSupportDirectory.appendingPathComponent("settings.json")
    }

    // MARK: - Session Persistence

    /// Save current scan session
    func saveSession(_ session: ScanSession) {
        do {
            let data = try encoder.encode(session)
            try data.write(to: sessionFile)
        } catch {
            print("Error saving session: \(error)")
        }
    }

    /// Load saved scan session
    func loadSession() -> ScanSession? {
        guard fileManager.fileExists(atPath: sessionFile.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: sessionFile)
            return try decoder.decode(ScanSession.self, from: data)
        } catch {
            print("Error loading session: \(error)")
            return nil
        }
    }

    /// Check if a saved session exists
    var hasSavedSession: Bool {
        fileManager.fileExists(atPath: sessionFile.path)
    }

    /// Clear saved session
    func clearSession() {
        try? fileManager.removeItem(at: sessionFile)
    }

    /// Get session info without loading full data
    func getSessionInfo() -> SessionInfo? {
        guard hasSavedSession else { return nil }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: sessionFile.path)
            let modificationDate = attributes[.modificationDate] as? Date ?? Date()
            let fileSize = attributes[.size] as? Int64 ?? 0

            // Quick peek at session data
            let data = try Data(contentsOf: sessionFile)
            if let session = try? decoder.decode(ScanSession.self, from: data) {
                return SessionInfo(
                    timestamp: session.timestamp,
                    progress: session.progress,
                    fileSize: fileSize,
                    modificationDate: modificationDate
                )
            }
        } catch {
            print("Error getting session info: \(error)")
        }

        return nil
    }

    // MARK: - Analysis Cache

    /// Save analysis cache for a batch of photos
    func saveAnalysisCache(_ analyses: [String: PhotoAnalysisCache]) {
        // Ensure cache directory exists
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }

        for (photoID, analysis) in analyses {
            let filename = sanitizeFilename(photoID) + ".json"
            let fileURL = cacheDirectory.appendingPathComponent(filename)

            do {
                let data = try encoder.encode(analysis)
                try data.write(to: fileURL)
            } catch {
                print("Error saving analysis cache for \(photoID): \(error)")
            }
        }
    }

    /// Load cached analysis for a photo
    func loadAnalysisCache(photoID: String) -> PhotoAnalysisCache? {
        let filename = sanitizeFilename(photoID) + ".json"
        let fileURL = cacheDirectory.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(PhotoAnalysisCache.self, from: data)
        } catch {
            print("Error loading analysis cache for \(photoID): \(error)")
            return nil
        }
    }

    /// Clear all analysis cache
    func clearAnalysisCache() {
        try? fileManager.removeItem(at: cacheDirectory)
    }

    /// Get cache size
    func getCacheSize() -> Int64 {
        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            return 0
        }

        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }

    // MARK: - Settings

    /// Save app settings
    func saveSettings(_ settings: AppSettings) {
        do {
            let data = try encoder.encode(settings)
            try data.write(to: settingsFile)
        } catch {
            print("Error saving settings: \(error)")
        }
    }

    /// Load app settings
    func loadSettings() -> AppSettings? {
        guard fileManager.fileExists(atPath: settingsFile.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: settingsFile)
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            print("Error loading settings: \(error)")
            return nil
        }
    }

    // MARK: - Incremental Scan State

    /// Save incremental scan state
    func saveIncrementalState(_ state: IncrementalScanState) {
        let stateFile = appSupportDirectory.appendingPathComponent("incremental_state.json")

        do {
            let data = try encoder.encode(state)
            try data.write(to: stateFile)
        } catch {
            print("Error saving incremental state: \(error)")
        }
    }

    /// Load incremental scan state
    func loadIncrementalState() -> IncrementalScanState? {
        let stateFile = appSupportDirectory.appendingPathComponent("incremental_state.json")

        guard fileManager.fileExists(atPath: stateFile.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: stateFile)
            return try decoder.decode(IncrementalScanState.self, from: data)
        } catch {
            print("Error loading incremental state: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private func sanitizeFilename(_ id: String) -> String {
        // Replace invalid filename characters
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return id.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}

// MARK: - Supporting Types

struct SessionInfo {
    let timestamp: Date
    let progress: ScanProgress
    let fileSize: Int64
    let modificationDate: Date

    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

struct PhotoAnalysisCache: Codable {
    let photoID: String
    let contentHash: String?
    let perceptualHash: String?
    let blurScore: Double?
    let brightnessScore: Double?
    let qualityScore: Double?
    let analyzedAt: Date
}

struct IncrementalScanState: Codable {
    /// Last modification date we've seen for each source
    var sourceLastModified: [String: Date] = [:]

    /// Set of photo IDs that have been analyzed
    var analyzedPhotoIDs: Set<String> = []

    /// Last full scan timestamp
    var lastFullScanDate: Date?

    /// Check if a photo needs to be re-analyzed
    func needsAnalysis(photoID: String, modificationDate: Date?) -> Bool {
        guard analyzedPhotoIDs.contains(photoID) else {
            return true // Never analyzed
        }

        // TODO: Check if photo was modified since last analysis
        return false
    }

    /// Mark a photo as analyzed
    mutating func markAnalyzed(_ photoID: String) {
        analyzedPhotoIDs.insert(photoID)
    }

    /// Update source last modified date
    mutating func updateSourceModified(_ sourceID: String, date: Date) {
        sourceLastModified[sourceID] = date
    }
}
