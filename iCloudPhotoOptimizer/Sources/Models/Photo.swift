import Foundation
import SwiftUI

/// Represents a photo in the library
struct Photo: Identifiable, Codable, Hashable {
    let id: String
    let filename: String
    let fileSize: Int64
    let creationDate: Date?
    let modificationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let location: PhotoLocation?
    let sourceType: PhotoSourceType
    let sourcePath: String?

    // Computed from analysis
    var qualityScore: Double?
    var blurScore: Double?
    var brightnessScore: Double?
    var contentHash: String?
    var perceptualHash: String?

    var resolution: String {
        "\(pixelWidth) × \(pixelHeight)"
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var megapixels: Double {
        Double(pixelWidth * pixelHeight) / 1_000_000.0
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.id == rhs.id
    }
}

/// Photo location (if available)
struct PhotoLocation: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let locationName: String?
}

/// Type of photo source
enum PhotoSourceType: String, Codable, CaseIterable {
    case iCloudLibrary = "iCloud Photos"
    case localFolder = "Local Folder"

    var icon: String {
        switch self {
        case .iCloudLibrary: return "icloud"
        case .localFolder: return "folder"
        }
    }
}

/// Represents a photo source (iCloud or local folder)
struct PhotoSource: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    let type: PhotoSourceType
    let path: String?
    var isEnabled: Bool
    var photoCount: Int = 0
    var scanStatus: ScanStatus = .pending

    enum ScanStatus: String, Codable {
        case pending = "Pending"
        case scanning = "Scanning"
        case scanned = "Scanned"
        case error = "Error"

        var icon: String {
            switch self {
            case .pending: return "clock"
            case .scanning: return "arrow.triangle.2.circlepath"
            case .scanned: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .pending: return .secondary
            case .scanning: return .blue
            case .scanned: return .green
            case .error: return .red
            }
        }
    }
}

/// Thumbnail representation for efficient display
struct PhotoThumbnail: Identifiable {
    let id: String
    let image: NSImage?
    let photo: Photo

    init(photo: Photo, image: NSImage? = nil) {
        self.id = photo.id
        self.photo = photo
        self.image = image
    }
}
