import Foundation

/// Parking guide line display styles.
enum GuideLineStyle: String, CaseIterable, Codable {
    /// Standard trajectory lines
    case standard
    /// Wide-body vehicle lines
    case wide
    /// Parking spot alignment lines
    case parking

    var displayName: String {
        switch self {
        case .standard:
            return "标准型"
        case .wide:
            return "宽体型"
        case .parking:
            return "停车位型"
        }
    }
}
