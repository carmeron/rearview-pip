import Foundation

/// Snapshot of the current video stream status, used for logging and diagnostics.
struct VideoStreamState: CustomStringConvertible {
    /// Current signal state
    let signalState: SignalState
    /// Most recent frame metrics (nil if no frame processed yet)
    let currentMetrics: FrameMetrics?
    /// Whether a UVC device is currently connected
    let deviceConnected: Bool
    /// Current capture frame rate
    let frameRate: Int
    /// Timestamp of the last state update
    let lastUpdateTime: Date

    var description: String {
        """
        VideoStreamState(
            signal: \(signalState.rawValue),
            deviceConnected: \(deviceConnected),
            frameRate: \(frameRate) fps,
            brightness: \(currentMetrics?.brightness ?? -1),
            contrast: \(currentMetrics?.contrast ?? -1),
            motion: \(currentMetrics?.motionMagnitude ?? -1),
            lastUpdate: \(lastUpdateTime)
        )
        """
    }
}
