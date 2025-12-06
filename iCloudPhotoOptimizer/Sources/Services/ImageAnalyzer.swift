import Foundation
import Vision
import CoreImage
import AppKit

/// Analyzes images for duplicates, similarity, and quality issues
actor ImageAnalyzer {

    // MARK: - Types

    struct AnalysisResult {
        var duplicates: [DuplicateGroup] = []
        var similar: [SimilarGroup] = []
        var qualityIssues: [QualityIssue] = []
    }

    struct PhotoAnalysis {
        let photo: Photo
        var contentHash: String?
        var perceptualHash: String?
        var blurScore: Double?
        var brightnessScore: Double?
        var qualityScore: Double?
        var featureVector: [Float]?
    }

    // MARK: - Properties

    private var analysisCache: [String: PhotoAnalysis] = [:]
    private let photoLibraryManager = PhotoLibraryManager()

    // MARK: - Batch Analysis

    /// Analyze a batch of photos for duplicates, similar photos, and quality issues
    func analyzeBatch(_ photos: [Photo], settings: AppSettings) async -> AnalysisResult {
        var result = AnalysisResult()
        var analyses: [PhotoAnalysis] = []

        // Step 1: Analyze each photo individually
        for photo in photos {
            let analysis = await analyzePhoto(photo, settings: settings)
            analyses.append(analysis)

            // Check for quality issues
            if let issues = detectQualityIssues(analysis, settings: settings) {
                result.qualityIssues.append(issues)
            }
        }

        // Step 2: Find duplicates (exact matches)
        result.duplicates = findDuplicates(analyses)

        // Step 3: Find similar photos
        result.similar = findSimilarPhotos(analyses, threshold: settings.similarityThreshold)

        return result
    }

    // MARK: - Individual Photo Analysis

    /// Analyze a single photo
    private func analyzePhoto(_ photo: Photo, settings: AppSettings) async -> PhotoAnalysis {
        // Check cache first
        if let cached = analysisCache[photo.id] {
            return cached
        }

        var analysis = PhotoAnalysis(photo: photo)

        // Load thumbnail for quick analysis
        if let thumbnail = await photoLibraryManager.loadThumbnail(for: photo, size: CGSize(width: 256, height: 256)) {
            // Calculate perceptual hash
            analysis.perceptualHash = await calculatePerceptualHash(thumbnail)

            // Analyze quality metrics
            if let ciImage = CIImage(data: thumbnail.tiffRepresentation ?? Data()) {
                analysis.blurScore = calculateBlurScore(ciImage)
                analysis.brightnessScore = calculateBrightness(ciImage)
            }

            // Calculate feature vector for similarity comparison
            analysis.featureVector = await extractFeatureVector(thumbnail)
        }

        // Calculate overall quality score
        analysis.qualityScore = calculateQualityScore(analysis)

        // Cache the result
        analysisCache[photo.id] = analysis

        return analysis
    }

    // MARK: - Duplicate Detection

    /// Find exact and near-exact duplicates
    private func findDuplicates(_ analyses: [PhotoAnalysis]) -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        var processedIDs = Set<String>()

        // Group by perceptual hash
        var hashGroups: [String: [PhotoAnalysis]] = [:]

        for analysis in analyses {
            guard let hash = analysis.perceptualHash else { continue }
            hashGroups[hash, default: []].append(analysis)
        }

        // Create duplicate groups
        for (_, groupAnalyses) in hashGroups {
            guard groupAnalyses.count > 1 else { continue }

            let photos = groupAnalyses.map { analysis -> Photo in
                var photo = analysis.photo
                photo.qualityScore = analysis.qualityScore
                photo.blurScore = analysis.blurScore
                photo.brightnessScore = analysis.brightnessScore
                photo.perceptualHash = analysis.perceptualHash
                return photo
            }

            // Determine match type
            let matchType: DuplicateMatchType
            if areExactDuplicates(groupAnalyses) {
                matchType = .exact
            } else if areNearExactDuplicates(groupAnalyses) {
                matchType = .nearExact
            } else {
                matchType = .sameContent
            }

            let group = DuplicateGroup(
                photos: photos,
                matchType: matchType,
                matchConfidence: 0.95
            )

            groups.append(group)

            for analysis in groupAnalyses {
                processedIDs.insert(analysis.photo.id)
            }
        }

        return groups
    }

    private func areExactDuplicates(_ analyses: [PhotoAnalysis]) -> Bool {
        guard analyses.count > 1 else { return false }

        // Check if all content hashes match (if available)
        let hashes = analyses.compactMap { $0.contentHash }
        guard hashes.count == analyses.count else { return false }

        return Set(hashes).count == 1
    }

    private func areNearExactDuplicates(_ analyses: [PhotoAnalysis]) -> Bool {
        guard analyses.count > 1 else { return false }

        // Check if all photos have similar dimensions and file sizes
        let sizes = analyses.map { ($0.photo.pixelWidth, $0.photo.pixelHeight) }
        let firstSize = sizes[0]

        return sizes.allSatisfy { abs($0.0 - firstSize.0) < 100 && abs($0.1 - firstSize.1) < 100 }
    }

    // MARK: - Similar Photo Detection

    /// Find similar but not duplicate photos
    private func findSimilarPhotos(_ analyses: [PhotoAnalysis], threshold: Double) -> [SimilarGroup] {
        var groups: [SimilarGroup] = []
        var processedIDs = Set<String>()

        // Group by capture time proximity first
        let timeGroups = groupByTimestamp(analyses, windowSeconds: 10)

        for timeGroup in timeGroups {
            guard timeGroup.count > 1 else { continue }

            // Further refine by visual similarity
            let similarSubgroups = clusterBySimilarity(timeGroup, threshold: threshold)

            for subgroup in similarSubgroups {
                guard subgroup.count > 1 else { continue }

                // Skip if already processed as duplicates
                let ids = Set(subgroup.map { $0.photo.id })
                guard ids.isDisjoint(with: processedIDs) else { continue }

                let photos = subgroup.map { analysis -> Photo in
                    var photo = analysis.photo
                    photo.qualityScore = analysis.qualityScore
                    photo.blurScore = analysis.blurScore
                    photo.brightnessScore = analysis.brightnessScore
                    return photo
                }

                let groupType = determineGroupType(subgroup)
                let similarity = calculateAverageSimilarity(subgroup)

                let group = SimilarGroup(
                    photos: photos,
                    similarityScore: similarity,
                    groupType: groupType,
                    captureDate: photos.first?.creationDate
                )

                groups.append(group)
                processedIDs.formUnion(ids)
            }
        }

        return groups
    }

    private func groupByTimestamp(_ analyses: [PhotoAnalysis], windowSeconds: TimeInterval) -> [[PhotoAnalysis]] {
        let sorted = analyses.sorted {
            ($0.photo.creationDate ?? .distantPast) < ($1.photo.creationDate ?? .distantPast)
        }

        var groups: [[PhotoAnalysis]] = []
        var currentGroup: [PhotoAnalysis] = []
        var lastDate: Date?

        for analysis in sorted {
            guard let date = analysis.photo.creationDate else { continue }

            if let last = lastDate, date.timeIntervalSince(last) <= windowSeconds {
                currentGroup.append(analysis)
            } else {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [analysis]
            }
            lastDate = date
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups
    }

    private func clusterBySimilarity(_ analyses: [PhotoAnalysis], threshold: Double) -> [[PhotoAnalysis]] {
        var clusters: [[PhotoAnalysis]] = []
        var remaining = analyses

        while !remaining.isEmpty {
            let seed = remaining.removeFirst()
            var cluster = [seed]

            var i = 0
            while i < remaining.count {
                if calculateSimilarity(seed, remaining[i]) >= threshold {
                    cluster.append(remaining.remove(at: i))
                } else {
                    i += 1
                }
            }

            clusters.append(cluster)
        }

        return clusters
    }

    private func calculateSimilarity(_ a: PhotoAnalysis, _ b: PhotoAnalysis) -> Double {
        guard let vecA = a.featureVector, let vecB = b.featureVector else {
            return 0.0
        }

        // Cosine similarity
        let dotProduct = zip(vecA, vecB).reduce(0.0) { $0 + Double($1.0 * $1.1) }
        let magnitudeA = sqrt(vecA.reduce(0.0) { $0 + Double($1 * $1) })
        let magnitudeB = sqrt(vecB.reduce(0.0) { $0 + Double($1 * $1) })

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }

    private func calculateAverageSimilarity(_ analyses: [PhotoAnalysis]) -> Double {
        guard analyses.count > 1 else { return 1.0 }

        var totalSimilarity = 0.0
        var count = 0

        for i in 0..<analyses.count {
            for j in (i+1)..<analyses.count {
                totalSimilarity += calculateSimilarity(analyses[i], analyses[j])
                count += 1
            }
        }

        return count > 0 ? totalSimilarity / Double(count) : 0.0
    }

    private func determineGroupType(_ analyses: [PhotoAnalysis]) -> SimilarGroupType {
        guard let firstDate = analyses.first?.photo.creationDate,
              let lastDate = analyses.last?.photo.creationDate else {
            return .similar
        }

        let timeSpan = lastDate.timeIntervalSince(firstDate)

        if timeSpan < 1.0 {
            return .burst
        } else if timeSpan < 10.0 {
            return .sequential
        } else {
            return .similar
        }
    }

    // MARK: - Quality Detection

    /// Detect quality issues in a photo
    private func detectQualityIssues(_ analysis: PhotoAnalysis, settings: AppSettings) -> QualityIssue? {
        var issues: [QualityIssueType] = []

        // Check blur
        if settings.detectBlurry, let blurScore = analysis.blurScore {
            if blurScore < settings.blurThreshold {
                issues.append(.blurry(score: blurScore))
            }
        }

        // Check darkness
        if settings.detectDark, let brightness = analysis.brightnessScore {
            if brightness < settings.darknessThreshold {
                issues.append(.dark(brightness: brightness))
            }
        }

        // Check overexposure
        if settings.detectOverexposed, let brightness = analysis.brightnessScore {
            if brightness > settings.brightnessThreshold {
                issues.append(.overexposed(brightness: brightness))
            }
        }

        // Check resolution
        if settings.detectLowResolution {
            let minDimension = min(analysis.photo.pixelWidth, analysis.photo.pixelHeight)
            if minDimension < settings.minimumResolution {
                issues.append(.lowResolution(width: analysis.photo.pixelWidth, height: analysis.photo.pixelHeight))
            }
        }

        guard !issues.isEmpty else { return nil }

        var photo = analysis.photo
        photo.qualityScore = analysis.qualityScore
        photo.blurScore = analysis.blurScore
        photo.brightnessScore = analysis.brightnessScore

        return QualityIssue(photo: photo, issues: issues)
    }

    // MARK: - Image Processing

    /// Calculate perceptual hash (pHash) for an image
    private func calculatePerceptualHash(_ image: NSImage) async -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // Resize to 32x32 and convert to grayscale
        let size = 32
        let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        guard let pixels = context?.data?.bindMemory(to: UInt8.self, capacity: size * size) else {
            return nil
        }

        // Calculate DCT and generate hash
        var hash: UInt64 = 0
        let avg = (0..<size*size).reduce(0) { $0 + Int(pixels[$1]) } / (size * size)

        for i in 0..<64 {
            if pixels[i] > avg {
                hash |= (1 << i)
            }
        }

        return String(format: "%016llx", hash)
    }

    /// Extract feature vector using Vision framework
    private func extractFeatureVector(_ image: NSImage) async -> [Float]? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                guard error == nil,
                      let observation = request.results?.first as? VNFeaturePrintObservation else {
                    continuation.resume(returning: nil)
                    return
                }

                var featureVector = [Float](repeating: 0, count: observation.elementCount)
                let data = observation.data
                data.withUnsafeBytes { bytes in
                    let floatBuffer = bytes.bindMemory(to: Float.self)
                    for i in 0..<observation.elementCount {
                        featureVector[i] = floatBuffer[i]
                    }
                }

                continuation.resume(returning: featureVector)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    /// Calculate blur score using Laplacian variance
    private func calculateBlurScore(_ image: CIImage) -> Double {
        let filter = CIFilter(name: "CILaplacian")
        filter?.setValue(image, forKey: kCIInputImageKey)

        guard let outputImage = filter?.outputImage else { return 100.0 }

        let context = CIContext()
        var bitmap = [Float](repeating: 0, count: 4)

        // Calculate variance of the Laplacian
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 16,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBAf,
            colorSpace: nil
        )

        // Higher variance = sharper image
        let variance = abs(bitmap[0]) * 1000
        return min(100.0, Double(variance))
    }

    /// Calculate average brightness
    private func calculateBrightness(_ image: CIImage) -> Double {
        let filter = CIFilter(name: "CIAreaAverage")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter?.outputImage else { return 0.5 }

        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 4)

        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        // Calculate luminance
        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0

        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    /// Calculate overall quality score
    private func calculateQualityScore(_ analysis: PhotoAnalysis) -> Double {
        var score = 100.0

        // Penalize blur
        if let blurScore = analysis.blurScore {
            if blurScore < 50 {
                score -= (50 - blurScore)
            }
        }

        // Penalize poor exposure
        if let brightness = analysis.brightnessScore {
            if brightness < 0.2 {
                score -= (0.2 - brightness) * 100
            } else if brightness > 0.8 {
                score -= (brightness - 0.8) * 100
            }
        }

        // Penalize low resolution
        let megapixels = analysis.photo.megapixels
        if megapixels < 1.0 {
            score -= (1.0 - megapixels) * 20
        }

        return max(0, min(100, score))
    }

    // MARK: - Cache Management

    /// Clear analysis cache
    func clearCache() {
        analysisCache.removeAll()
    }

    /// Get cached analysis for a photo
    func getCachedAnalysis(for photoID: String) -> PhotoAnalysis? {
        return analysisCache[photoID]
    }
}
