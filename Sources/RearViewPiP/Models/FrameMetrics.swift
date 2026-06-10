import CoreMedia

/// Metrics extracted from a single video frame analysis.
struct FrameMetrics: Equatable {
    /// Average brightness [0-255]
    let brightness: Float
    /// Contrast as standard deviation of pixel brightness
    let contrast: Float
    /// Motion magnitude compared to previous frame [0-255]
    let motionMagnitude: Float
    /// Timestamp of the analyzed frame
    let timestamp: CMTime

    /// Returns true if this frame appears to be a valid signal (not a black/no-signal screen)
    var hasValidSignal: Bool {
        brightness > 10.0 || contrast > 5.0
    }

    /// Returns true if motion or brightness suggests active video content
    var suggestsActiveVideo: Bool {
        motionMagnitude > 5.0 || brightness > 50.0
    }

    /// Zero-value metrics for initial state
    static let zero = FrameMetrics(
        brightness: 0,
        contrast: 0,
        motionMagnitude: 0,
        timestamp: .zero
    )
}
