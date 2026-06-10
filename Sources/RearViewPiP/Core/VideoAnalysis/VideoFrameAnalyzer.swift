import Foundation
import CoreVideo
import CoreMedia

/// Analyzes video frames to extract brightness, contrast, and motion metrics.
final class VideoFrameAnalyzer {
    /// The last processed frame for motion comparison
    private var lastFrameMetrics: FrameMetrics?
    /// Serial queue for frame analysis to avoid data races
    private let analysisQueue = DispatchQueue(label: "com.rearviewpip.frameanalysis", qos: .userInitiated)

    // MARK: - Public API

    /// Analyze a single pixel buffer and return frame metrics.
    /// - Parameters:
    ///   - pixelBuffer: The current video frame
    ///   - previousPixelBuffer: Optional previous frame for motion detection
    /// - Returns: Extracted FrameMetrics
    func analyze(pixelBuffer: CVPixelBuffer,
                 previousPixelBuffer: CVPixelBuffer?) -> FrameMetrics {
        let brightness = calculateBrightness(pixelBuffer)
        let contrast = calculateContrast(pixelBuffer, meanBrightness: brightness)

        var motion: Float = 0
        if let previous = previousPixelBuffer {
            motion = calculateMotion(current: pixelBuffer, previous: previous)
        }

        return FrameMetrics(
            brightness: brightness,
            contrast: contrast,
            motionMagnitude: motion,
            timestamp: .zero  // Set by caller
        )
    }

    /// Calculate the average perceptual brightness of a pixel buffer.
    /// Uses luminance formula: Y = 0.299*R + 0.587*G + 0.114*B
    /// Samples every 4th pixel for performance.
    func calculateBrightness(_ pixelBuffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0
        }

        let sampleStep = 4  // Downsample: sample every 4th pixel
        var totalBrightness: Float = 0
        var sampleCount: Int = 0

        let rowBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        for y in stride(from: 0, to: height, by: sampleStep) {
            let rowOffset = y * bytesPerRow
            for x in stride(from: 0, to: width * 4, by: sampleStep * 4) {
                let offset = rowOffset + x
                guard offset + 2 < bytesPerRow * height else { continue }

                let r = Float(rowBuffer[offset])
                let g = Float(rowBuffer[offset + 1])
                let b = Float(rowBuffer[offset + 2])

                // Perceptual luminance formula
                let pixelBrightness = 0.299 * r + 0.587 * g + 0.114 * b
                totalBrightness += pixelBrightness
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return 0 }
        return totalBrightness / Float(sampleCount)
    }

    /// Calculate contrast as the standard deviation of pixel brightness values.
    /// - Parameters:
    ///   - pixelBuffer: The video frame
    ///   - meanBrightness: Pre-computed mean brightness
    /// - Returns: Standard deviation as contrast metric
    func calculateContrast(_ pixelBuffer: CVPixelBuffer,
                           meanBrightness: Float? = nil) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let brightness = meanBrightness ?? calculateBrightness(pixelBuffer)

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0
        }

        let sampleStep = 4
        var varianceSum: Float = 0
        var sampleCount: Int = 0

        let rowBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        for y in stride(from: 0, to: height, by: sampleStep) {
            let rowOffset = y * bytesPerRow
            for x in stride(from: 0, to: width * 4, by: sampleStep * 4) {
                let offset = rowOffset + x
                guard offset + 2 < bytesPerRow * height else { continue }

                let r = Float(rowBuffer[offset])
                let g = Float(rowBuffer[offset + 1])
                let b = Float(rowBuffer[offset + 2])

                let pixelBrightness = 0.299 * r + 0.587 * g + 0.114 * b
                let diff = pixelBrightness - brightness
                varianceSum += diff * diff
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return 0 }
        // Standard deviation as contrast indicator
        return sqrt(varianceSum / Float(sampleCount))
    }

    /// Calculate motion magnitude by comparing two consecutive frames.
    /// Uses pixel difference sum, normalized to [0-255].
    /// Samples every 8th pixel for performance.
    /// - Parameters:
    ///   - current: The current video frame
    ///   - previous: The previous video frame
    /// - Returns: Average per-channel pixel difference
    func calculateMotion(current: CVPixelBuffer,
                         previous: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(current, .readOnly)
        CVPixelBufferLockBaseAddress(previous, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(current, .readOnly)
            CVPixelBufferUnlockBaseAddress(previous, .readOnly)
        }

        let width = CVPixelBufferGetWidth(current)
        let height = CVPixelBufferGetHeight(current)
        let currentBytesPerRow = CVPixelBufferGetBytesPerRow(current)
        let previousBytesPerRow = CVPixelBufferGetBytesPerRow(previous)

        guard let currentBase = CVPixelBufferGetBaseAddress(current),
              let previousBase = CVPixelBufferGetBaseAddress(previous) else {
            return 0
        }

        let sampleStep = 8  // Larger step for performance
        var motionSum: Float = 0
        var sampleCount: Int = 0

        let currentRows = currentBase.assumingMemoryBound(to: UInt8.self)
        let previousRows = previousBase.assumingMemoryBound(to: UInt8.self)

        for y in stride(from: 0, to: height, by: sampleStep) {
            let currentRowOffset = y * currentBytesPerRow
            let previousRowOffset = y * previousBytesPerRow

            for x in stride(from: 0, to: width * 4, by: sampleStep * 4) {
                let currentOffset = currentRowOffset + x
                let previousOffset = previousRowOffset + x
                guard currentOffset + 2 < currentBytesPerRow * height,
                      previousOffset + 2 < previousBytesPerRow * height else { continue }

                let currR = Float(currentRows[currentOffset])
                let currG = Float(currentRows[currentOffset + 1])
                let currB = Float(currentRows[currentOffset + 2])

                let prevR = Float(previousRows[previousOffset])
                let prevG = Float(previousRows[previousOffset + 1])
                let prevB = Float(previousRows[previousOffset + 2])

                // Sum of absolute channel differences
                let diff = abs(currR - prevR) + abs(currG - prevG) + abs(currB - prevB)
                motionSum += diff
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return 0 }
        // Normalize to [0-255] range (divide by 3 channels)
        return motionSum / Float(sampleCount) / 3.0
    }
}
