import Foundation

/// Configurable thresholds for signal state detection.
struct DetectionThresholds: Equatable {
    /// Brightness below this value (combined with low contrast) indicates disconnected
    var brightnessDisconnected: Float = 10.0
    /// Contrast below this value (combined with low brightness) indicates disconnected
    var contrastDisconnected: Float = 5.0
    /// Brightness above this value indicates active video
    var brightnessActive: Float = 50.0
    /// Motion magnitude above this value indicates active video
    var motionActive: Float = 5.0

    /// Default thresholds (medium sensitivity)
    static let `default` = DetectionThresholds()

    /// Returns thresholds adjusted for the given sensitivity level.
    static func adjusted(for sensitivity: Sensitivity) -> DetectionThresholds {
        switch sensitivity {
        case .low:
            return DetectionThresholds(
                brightnessDisconnected: 15.0,
                contrastDisconnected: 8.0,
                brightnessActive: 70.0,
                motionActive: 10.0
            )
        case .medium:
            return DetectionThresholds(
                brightnessDisconnected: 10.0,
                contrastDisconnected: 5.0,
                brightnessActive: 50.0,
                motionActive: 5.0
            )
        case .high:
            return DetectionThresholds(
                brightnessDisconnected: 5.0,
                contrastDisconnected: 3.0,
                brightnessActive: 30.0,
                motionActive: 3.0
            )
        }
    }
}
