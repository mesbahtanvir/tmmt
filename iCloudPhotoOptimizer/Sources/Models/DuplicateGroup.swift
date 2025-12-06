import Foundation

/// Represents a group of duplicate photos
struct DuplicateGroup: Identifiable, Codable {
    let id: String
    let photos: [Photo]
    let matchType: DuplicateMatchType
    let matchConfidence: Double
    var recommendedKeepIndex: Int
    var userSelection: Set<Int> = []

    init(
        id: String = UUID().uuidString,
        photos: [Photo],
        matchType: DuplicateMatchType,
        matchConfidence: Double = 1.0
    ) {
        self.id = id
        self.photos = photos
        self.matchType = matchType
        self.matchConfidence = matchConfidence
        self.recommendedKeepIndex = Self.calculateRecommendedKeep(photos: photos)
    }

    /// Calculate which photo to keep based on quality metrics
    private static func calculateRecommendedKeep(photos: [Photo]) -> Int {
        // Prefer: higher resolution, larger file size, earlier creation date
        var bestIndex = 0
        var bestScore = 0.0

        for (index, photo) in photos.enumerated() {
            var score = 0.0

            // Resolution score (normalized)
            let pixels = Double(photo.pixelWidth * photo.pixelHeight)
            score += pixels / 10_000_000.0 // Normalize to ~1.0 for 10MP

            // File size score (larger often means better quality)
            score += Double(photo.fileSize) / 5_000_000.0 // Normalize to ~1.0 for 5MB

            // Quality score if available
            if let qualityScore = photo.qualityScore {
                score += qualityScore
            }

            // Prefer original location (iCloud over local copies)
            if photo.sourceType == .iCloudLibrary {
                score += 0.5
            }

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        return bestIndex
    }

    /// Total size of all photos in group
    var totalSize: Int64 {
        photos.reduce(0) { $0 + $1.fileSize }
    }

    /// Potential savings if keeping only recommended photo
    var potentialSavings: Int64 {
        let keepSize = photos.indices.contains(recommendedKeepIndex)
            ? photos[recommendedKeepIndex].fileSize
            : 0
        return totalSize - keepSize
    }

    /// Photos marked for deletion
    var photosToDelete: [Photo] {
        photos.enumerated()
            .filter { $0.offset != recommendedKeepIndex }
            .map { $0.element }
    }

    /// The photo recommended to keep
    var recommendedPhoto: Photo? {
        photos.indices.contains(recommendedKeepIndex) ? photos[recommendedKeepIndex] : nil
    }
}

/// Type of duplicate match
enum DuplicateMatchType: String, Codable {
    case exact = "Exact Match"
    case nearExact = "Near-Exact"
    case sameContent = "Same Content"

    var description: String {
        switch self {
        case .exact:
            return "100% identical (SHA256 hash match)"
        case .nearExact:
            return "Same image, different metadata or compression"
        case .sameContent:
            return "Visually identical content"
        }
    }

    var icon: String {
        switch self {
        case .exact: return "equal.circle.fill"
        case .nearExact: return "equal.circle"
        case .sameContent: return "photo.on.rectangle"
        }
    }

    var priority: Int {
        switch self {
        case .exact: return 0
        case .nearExact: return 1
        case .sameContent: return 2
        }
    }
}
