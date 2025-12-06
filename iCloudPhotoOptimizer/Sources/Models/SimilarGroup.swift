import Foundation

/// Represents a group of similar (but not duplicate) photos
struct SimilarGroup: Identifiable, Codable {
    let id: String
    let photos: [Photo]
    let similarityScore: Double
    let groupType: SimilarGroupType
    let captureDate: Date?
    let eventDescription: String?
    var recommendedKeepIndices: Set<Int>
    var userSelection: Set<Int> = []

    init(
        id: String = UUID().uuidString,
        photos: [Photo],
        similarityScore: Double,
        groupType: SimilarGroupType,
        captureDate: Date? = nil,
        eventDescription: String? = nil
    ) {
        self.id = id
        self.photos = photos
        self.similarityScore = similarityScore
        self.groupType = groupType
        self.captureDate = captureDate
        self.eventDescription = eventDescription
        self.recommendedKeepIndices = Self.calculateRecommendedKeeps(photos: photos)
    }

    /// Determine which photos to keep (best quality ones)
    private static func calculateRecommendedKeeps(photos: [Photo]) -> Set<Int> {
        guard !photos.isEmpty else { return [] }

        // Score each photo
        let scored = photos.enumerated().map { (index, photo) -> (Int, Double) in
            var score = 0.0

            // Quality score (0-100)
            if let qualityScore = photo.qualityScore {
                score += qualityScore
            } else {
                score += 50.0 // Default if not analyzed
            }

            // Penalize blur
            if let blurScore = photo.blurScore, blurScore < 100 {
                score -= (100 - blurScore) * 0.5
            }

            // Bonus for good exposure
            if let brightness = photo.brightnessScore,
               brightness > 0.3 && brightness < 0.7 {
                score += 10
            }

            return (index, score)
        }

        // Sort by score descending
        let sorted = scored.sorted { $0.1 > $1.1 }

        // Keep the best one by default
        return [sorted[0].0]
    }

    /// Total size of all photos in group
    var totalSize: Int64 {
        photos.reduce(0) { $0 + $1.fileSize }
    }

    /// Potential savings if keeping only recommended photos
    var potentialSavings: Int64 {
        let keepSize = photos.enumerated()
            .filter { recommendedKeepIndices.contains($0.offset) }
            .reduce(0) { $0 + $1.element.fileSize }
        return totalSize - keepSize
    }

    /// Photos marked for deletion
    var photosToDelete: [Photo] {
        photos.enumerated()
            .filter { !recommendedKeepIndices.contains($0.offset) }
            .map { $0.element }
    }

    /// Formatted date string
    var formattedDate: String? {
        guard let date = captureDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Display title for the group
    var displayTitle: String {
        if let event = eventDescription {
            return event
        }
        if let date = formattedDate {
            return date
        }
        return "Similar Photos"
    }
}

/// Type of similar photo grouping
enum SimilarGroupType: String, Codable {
    case burst = "Burst Photos"
    case sequential = "Sequential Shots"
    case similar = "Similar Scene"
    case sameSubject = "Same Subject"

    var description: String {
        switch self {
        case .burst:
            return "Photos taken in rapid succession (burst mode)"
        case .sequential:
            return "Photos taken within seconds of each other"
        case .similar:
            return "Photos with similar visual content"
        case .sameSubject:
            return "Photos featuring the same subject/person"
        }
    }

    var icon: String {
        switch self {
        case .burst: return "square.stack.3d.down.right"
        case .sequential: return "photo.stack"
        case .similar: return "rectangle.on.rectangle"
        case .sameSubject: return "person.2.crop.square.stack"
        }
    }
}
