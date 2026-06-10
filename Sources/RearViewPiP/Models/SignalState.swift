import Foundation

/// Represents the current signal state of the video input.
enum SignalState: String, Equatable, CaseIterable {
    /// No device connected or no signal detected
    case disconnected
    /// Device connected but no active video signal (normal driving)
    case idle
    /// Active video signal detected (reversing)
    case active

    /// Human-readable description for UI display
    var displayName: String {
        switch self {
        case .disconnected:
            return "设备未连接"
        case .idle:
            return "待命中"
        case .active:
            return "倒车中"
        }
    }
}
