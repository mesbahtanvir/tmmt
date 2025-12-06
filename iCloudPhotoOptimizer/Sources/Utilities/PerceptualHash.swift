import Foundation
import AppKit
import Accelerate

/// Perceptual hashing algorithms for image similarity detection
struct PerceptualHash {

    // MARK: - Average Hash (aHash)

    /// Calculate average hash - fast but less accurate
    /// Good for finding exact duplicates with minor modifications
    static func averageHash(_ image: NSImage, size: Int = 8) -> UInt64? {
        guard let resized = resize(image, to: CGSize(width: size, height: size)),
              let grayscale = toGrayscale(resized) else {
            return nil
        }

        let pixels = getPixels(grayscale)
        guard pixels.count == size * size else { return nil }

        let average = pixels.reduce(0, +) / Double(pixels.count)

        var hash: UInt64 = 0
        for (index, pixel) in pixels.enumerated() {
            if pixel > average {
                hash |= (1 << index)
            }
        }

        return hash
    }

    // MARK: - Difference Hash (dHash)

    /// Calculate difference hash - fast and more robust than aHash
    /// Compares adjacent pixels to detect relative brightness changes
    static func differenceHash(_ image: NSImage, size: Int = 8) -> UInt64? {
        // Resize to size+1 width to compare adjacent pixels
        guard let resized = resize(image, to: CGSize(width: size + 1, height: size)),
              let grayscale = toGrayscale(resized) else {
            return nil
        }

        let pixels = getPixels(grayscale)
        guard pixels.count == (size + 1) * size else { return nil }

        var hash: UInt64 = 0
        var bitIndex = 0

        for row in 0..<size {
            for col in 0..<size {
                let leftPixel = pixels[row * (size + 1) + col]
                let rightPixel = pixels[row * (size + 1) + col + 1]

                if leftPixel > rightPixel {
                    hash |= (1 << bitIndex)
                }
                bitIndex += 1
            }
        }

        return hash
    }

    // MARK: - Perceptual Hash (pHash)

    /// Calculate perceptual hash using DCT - more accurate but slower
    /// Best for finding visually similar images
    static func perceptualHash(_ image: NSImage, size: Int = 32, hashSize: Int = 8) -> UInt64? {
        guard let resized = resize(image, to: CGSize(width: size, height: size)),
              let grayscale = toGrayscale(resized) else {
            return nil
        }

        let pixels = getPixels(grayscale)
        guard pixels.count == size * size else { return nil }

        // Apply DCT
        let dctResult = dct2D(pixels, size: size)

        // Use top-left 8x8 of DCT (low frequencies)
        var lowFreq: [Double] = []
        for row in 0..<hashSize {
            for col in 0..<hashSize {
                lowFreq.append(dctResult[row * size + col])
            }
        }

        // Calculate median (excluding DC component)
        let sorted = lowFreq.dropFirst().sorted()
        let median = sorted[sorted.count / 2]

        // Generate hash
        var hash: UInt64 = 0
        for (index, value) in lowFreq.enumerated() {
            if index == 0 { continue } // Skip DC component
            if value > median {
                hash |= (1 << (index - 1))
            }
        }

        return hash
    }

    // MARK: - Hamming Distance

    /// Calculate Hamming distance between two hashes
    /// Lower distance = more similar
    static func hammingDistance(_ hash1: UInt64, _ hash2: UInt64) -> Int {
        let xor = hash1 ^ hash2
        return xor.nonzeroBitCount
    }

    /// Calculate similarity percentage (0.0 to 1.0)
    static func similarity(_ hash1: UInt64, _ hash2: UInt64, hashBits: Int = 64) -> Double {
        let distance = hammingDistance(hash1, hash2)
        return 1.0 - (Double(distance) / Double(hashBits))
    }

    // MARK: - Private Helpers

    private static func resize(_ image: NSImage, to size: CGSize) -> NSImage? {
        let newImage = NSImage(size: size)
        newImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )

        newImage.unlockFocus()
        return newImage
    }

    private static func toGrayscale(_ image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let grayCGImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: grayCGImage, size: image.size)
    }

    private static func getPixels(_ image: NSImage) -> [Double] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        let width = cgImage.width
        let height = cgImage.height

        var pixels = [UInt8](repeating: 0, count: width * height)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return []
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixels.map { Double($0) }
    }

    /// 2D Discrete Cosine Transform
    private static func dct2D(_ pixels: [Double], size: Int) -> [Double] {
        var result = [Double](repeating: 0, count: size * size)

        // Row-wise DCT
        var temp = [Double](repeating: 0, count: size * size)
        for row in 0..<size {
            let rowStart = row * size
            let rowPixels = Array(pixels[rowStart..<(rowStart + size)])
            let rowDCT = dct1D(rowPixels)
            for col in 0..<size {
                temp[row * size + col] = rowDCT[col]
            }
        }

        // Column-wise DCT
        for col in 0..<size {
            var colPixels = [Double](repeating: 0, count: size)
            for row in 0..<size {
                colPixels[row] = temp[row * size + col]
            }
            let colDCT = dct1D(colPixels)
            for row in 0..<size {
                result[row * size + col] = colDCT[row]
            }
        }

        return result
    }

    /// 1D Discrete Cosine Transform
    private static func dct1D(_ input: [Double]) -> [Double] {
        let n = input.count
        var output = [Double](repeating: 0, count: n)

        for k in 0..<n {
            var sum = 0.0
            for i in 0..<n {
                sum += input[i] * cos(Double.pi * Double(k) * (Double(i) + 0.5) / Double(n))
            }

            let alpha = k == 0 ? sqrt(1.0 / Double(n)) : sqrt(2.0 / Double(n))
            output[k] = alpha * sum
        }

        return output
    }
}

// MARK: - Hash String Conversion

extension UInt64 {
    /// Convert hash to hex string
    var hashString: String {
        String(format: "%016llx", self)
    }
}

extension String {
    /// Parse hex string to hash
    var hashValue: UInt64? {
        UInt64(self, radix: 16)
    }
}
