import Foundation
import CoreVideo

/// A pool for reusing CVPixelBuffer instances to reduce memory allocation overhead.
final class PixelBufferPool {
    private var pool: [CVPixelBuffer] = []
    private let maxPoolSize: Int
    private let lock = NSLock()

    /// Create a pixel buffer pool.
    /// - Parameter maxPoolSize: Maximum number of buffers to retain in the pool (default: 5)
    init(maxPoolSize: Int = 5) {
        self.maxPoolSize = maxPoolSize
    }

    /// Get a reusable pixel buffer, or create a new one if the pool is empty.
    /// - Parameters:
    ///   - width: Desired buffer width
    ///   - height: Desired buffer height
    /// - Returns: A CVPixelBuffer matching the requested dimensions, or nil if creation fails
    func getBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }

        // Try to find a matching buffer in the pool
        if let index = pool.firstIndex(where: { buffer in
            CVPixelBufferGetWidth(buffer) == width &&
            CVPixelBufferGetHeight(buffer) == height
        }) {
            let buffer = pool.remove(at: index)
            return buffer
        }

        // Create a new buffer
        return createNewBuffer(width: width, height: height)
    }

    /// Return a buffer to the pool for reuse.
    /// - Parameter buffer: The CVPixelBuffer to recycle
    func returnBuffer(_ buffer: CVPixelBuffer) {
        lock.lock()
        defer { lock.unlock() }

        guard pool.count < maxPoolSize else { return }
        pool.append(buffer)
    }

    /// Clear all buffers from the pool.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        pool.removeAll()
    }

    /// Current number of buffers in the pool.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return pool.count
    }

    // MARK: - Private

    private func createNewBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferBytesPerRowAlignmentKey: 64,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
            kCVPixelBufferMetalCompatibilityKey: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess else {
            #if DEBUG
            print("[PixelBufferPool] Failed to create buffer: \(status)")
            #endif
            return nil
        }

        return pixelBuffer
    }
}
