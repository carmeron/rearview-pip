import Foundation

/// A logged error entry for diagnostics.
struct ErrorLog: Codable {
    /// When the error occurred
    let timestamp: Date
    /// Category of the error
    let errorType: ErrorType
    /// Human-readable error description
    let message: String
    /// System state snapshot at time of error
    let systemState: String

    /// Categories of errors that can occur in the system.
    enum ErrorType: String, Codable {
        case deviceConnection
        case videoCapture
        case signalDetection
        case pipWindow
        case backgroundKeepAlive
    }
}
