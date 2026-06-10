import Foundation

/// Persistable application configuration.
struct AppConfiguration: Codable, Equatable {
    /// Selected guide line style
    var guideLineStyle: GuideLineStyle
    /// Whether visual alerts (red border flash) are enabled
    var visualAlertsEnabled: Bool
    /// Detection sensitivity level
    var detectionSensitivity: Sensitivity
    /// Saved PiP window frame (nil until user positions it)
    var pipWindowFrame: CGRect?
    /// Whether the initial setup wizard has been completed
    var setupCompleted: Bool

    /// Default configuration for first launch
    static var `default`: AppConfiguration {
        AppConfiguration(
            guideLineStyle: .standard,
            visualAlertsEnabled: true,
            detectionSensitivity: .medium,
            pipWindowFrame: nil,
            setupCompleted: false
        )
    }
}

/// Detection sensitivity levels for signal analysis.
enum Sensitivity: String, CaseIterable, Codable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low:
            return "低"
        case .medium:
            return "中"
        case .high:
            return "高"
        }
    }
}
