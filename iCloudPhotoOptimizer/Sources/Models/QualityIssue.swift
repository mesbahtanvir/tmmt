import Foundation
import SwiftUI

/// Represents a photo with quality issues
struct QualityIssue: Identifiable, Codable {
    let id: String
    let photo: Photo
    let issues: [QualityIssueType]
    let overallScore: Double
    var isSelected: Bool = false

    init(photo: Photo, issues: [QualityIssueType]) {
        self.id = photo.id
        self.photo = photo
        self.issues = issues
        self.overallScore = Self.calculateOverallScore(issues: issues)
    }

    private static func calculateOverallScore(issues: [QualityIssueType]) -> Double {
        guard !issues.isEmpty else { return 100.0 }

        // Start with 100 and subtract based on issues
        var score = 100.0
        for issue in issues {
            score -= issue.severityPenalty
        }
        return max(0, score)
    }

    /// Primary issue (most severe)
    var primaryIssue: QualityIssueType? {
        issues.max(by: { $0.severityPenalty < $1.severityPenalty })
    }

    /// Formatted score string
    var scoreString: String {
        String(format: "%.0f", overallScore)
    }
}

/// Types of quality issues detected
enum QualityIssueType: Codable, Hashable {
    case blurry(score: Double)
    case dark(brightness: Double)
    case overexposed(brightness: Double)
    case lowResolution(width: Int, height: Int)
    case noisy(level: Double)
    case badComposition

    var displayName: String {
        switch self {
        case .blurry: return "Blurry"
        case .dark: return "Too Dark"
        case .overexposed: return "Overexposed"
        case .lowResolution: return "Low Resolution"
        case .noisy: return "Noisy"
        case .badComposition: return "Bad Composition"
        }
    }

    var icon: String {
        switch self {
        case .blurry: return "camera.metering.unknown"
        case .dark: return "moon.fill"
        case .overexposed: return "sun.max.fill"
        case .lowResolution: return "arrow.down.right.and.arrow.up.left"
        case .noisy: return "waveform"
        case .badComposition: return "crop"
        }
    }

    var color: Color {
        switch self {
        case .blurry: return .purple
        case .dark: return .indigo
        case .overexposed: return .yellow
        case .lowResolution: return .orange
        case .noisy: return .gray
        case .badComposition: return .brown
        }
    }

    var severityPenalty: Double {
        switch self {
        case .blurry(let score):
            // Lower blur score = more blurry = higher penalty
            return max(0, 50 - score * 0.5)
        case .dark(let brightness):
            return (0.3 - brightness) * 100
        case .overexposed(let brightness):
            return (brightness - 0.7) * 100
        case .lowResolution:
            return 30
        case .noisy(let level):
            return level * 40
        case .badComposition:
            return 20
        }
    }

    var description: String {
        switch self {
        case .blurry(let score):
            return String(format: "Blur score: %.1f (low is blurry)", score)
        case .dark(let brightness):
            return String(format: "Brightness: %.0f%% (too dark)", brightness * 100)
        case .overexposed(let brightness):
            return String(format: "Brightness: %.0f%% (too bright)", brightness * 100)
        case .lowResolution(let width, let height):
            return "Resolution: \(width)×\(height)"
        case .noisy(let level):
            return String(format: "Noise level: %.0f%%", level * 100)
        case .badComposition:
            return "Poor framing or composition detected"
        }
    }
}

/// Filter options for quality issues view
struct QualityIssueFilter {
    var showBlurry: Bool = true
    var showDark: Bool = true
    var showOverexposed: Bool = true
    var showLowResolution: Bool = false
    var showNoisy: Bool = true
    var minimumScore: Double = 0
    var maximumScore: Double = 50

    func matches(_ issue: QualityIssue) -> Bool {
        // Check score range
        guard issue.overallScore >= minimumScore && issue.overallScore <= maximumScore else {
            return false
        }

        // Check if any enabled filter matches
        for issueType in issue.issues {
            switch issueType {
            case .blurry: if showBlurry { return true }
            case .dark: if showDark { return true }
            case .overexposed: if showOverexposed { return true }
            case .lowResolution: if showLowResolution { return true }
            case .noisy: if showNoisy { return true }
            case .badComposition: return true
            }
        }

        return false
    }
}
