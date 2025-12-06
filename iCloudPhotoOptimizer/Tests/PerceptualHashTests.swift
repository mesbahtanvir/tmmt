import XCTest
@testable import iCloudPhotoOptimizer

final class PerceptualHashTests: XCTestCase {

    // MARK: - Hamming Distance Tests

    func testHammingDistanceIdentical() {
        let hash: UInt64 = 0xABCDEF1234567890
        XCTAssertEqual(PerceptualHash.hammingDistance(hash, hash), 0)
    }

    func testHammingDistanceOneBitDifferent() {
        let hash1: UInt64 = 0b1111111111111111
        let hash2: UInt64 = 0b1111111111111110
        XCTAssertEqual(PerceptualHash.hammingDistance(hash1, hash2), 1)
    }

    func testHammingDistanceAllBitsDifferent() {
        let hash1: UInt64 = 0x0000000000000000
        let hash2: UInt64 = 0xFFFFFFFFFFFFFFFF
        XCTAssertEqual(PerceptualHash.hammingDistance(hash1, hash2), 64)
    }

    // MARK: - Similarity Tests

    func testSimilarityIdentical() {
        let hash: UInt64 = 0xABCDEF1234567890
        XCTAssertEqual(PerceptualHash.similarity(hash, hash), 1.0)
    }

    func testSimilarityOneBitDifferent() {
        let hash1: UInt64 = 0xFFFFFFFFFFFFFFFF
        let hash2: UInt64 = 0xFFFFFFFFFFFFFFFE
        let similarity = PerceptualHash.similarity(hash1, hash2)
        XCTAssertEqual(similarity, 63.0 / 64.0, accuracy: 0.001)
    }

    func testSimilarityCompleteDifferent() {
        let hash1: UInt64 = 0x0000000000000000
        let hash2: UInt64 = 0xFFFFFFFFFFFFFFFF
        XCTAssertEqual(PerceptualHash.similarity(hash1, hash2), 0.0)
    }

    // MARK: - Hash String Conversion Tests

    func testHashToString() {
        let hash: UInt64 = 0xABCDEF1234567890
        XCTAssertEqual(hash.hashString, "abcdef1234567890")
    }

    func testStringToHash() {
        let hashString = "abcdef1234567890"
        XCTAssertEqual(hashString.hashValue, 0xABCDEF1234567890)
    }

    func testInvalidHashString() {
        let invalid = "not-a-hash"
        XCTAssertNil(invalid.hashValue)
    }
}

final class ExtensionsTests: XCTestCase {

    // MARK: - Date Extensions

    func testDateShortFormatted() {
        let date = Date()
        let formatted = date.shortFormatted
        XCTAssertFalse(formatted.isEmpty)
    }

    func testDateMediumFormatted() {
        let date = Date()
        let formatted = date.mediumFormatted
        XCTAssertFalse(formatted.isEmpty)
    }

    // MARK: - Int64 Extensions

    func testFormattedBytes() {
        XCTAssertEqual(Int64(1024).formattedBytes, "1 KB")
        XCTAssertEqual(Int64(1024 * 1024).formattedBytes, "1 MB")
        XCTAssertEqual(Int64(1024 * 1024 * 1024).formattedBytes, "1 GB")
    }

    // MARK: - Collection Extensions

    func testSafeSubscript() {
        let array = [1, 2, 3]
        XCTAssertEqual(array[safe: 0], 1)
        XCTAssertEqual(array[safe: 2], 3)
        XCTAssertNil(array[safe: 5])
        XCTAssertNil(array[safe: -1])
    }

    // MARK: - String Extensions

    func testTruncated() {
        let long = "This is a very long string"
        XCTAssertEqual(long.truncated(to: 10), "This is a …")
        XCTAssertEqual("Short".truncated(to: 10), "Short")
    }
}

final class ArrayChunkedTests: XCTestCase {

    func testChunkedEvenDivision() {
        let array = [1, 2, 3, 4, 5, 6]
        let chunks = array.chunked(into: 2)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], [1, 2])
        XCTAssertEqual(chunks[1], [3, 4])
        XCTAssertEqual(chunks[2], [5, 6])
    }

    func testChunkedUnevenDivision() {
        let array = [1, 2, 3, 4, 5]
        let chunks = array.chunked(into: 2)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], [1, 2])
        XCTAssertEqual(chunks[1], [3, 4])
        XCTAssertEqual(chunks[2], [5])
    }

    func testChunkedEmpty() {
        let array: [Int] = []
        let chunks = array.chunked(into: 2)
        XCTAssertTrue(chunks.isEmpty)
    }

    func testChunkedSingleElement() {
        let array = [1]
        let chunks = array.chunked(into: 5)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], [1])
    }
}
