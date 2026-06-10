import CoreVideo

/// Content types that can be displayed in the PiP window.
enum PiPContent {
    /// Standby logo when no active signal
    case logo
    /// Live video feed with optional guide line overlay
    case video(CVPixelBuffer, GuideLineStyle?)
    /// Error message when device disconnected or error occurs
    case error(String)
}
