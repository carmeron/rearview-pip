import Foundation

/// Application-specific errors with localized descriptions.
enum RearViewPiPError: LocalizedError {
    case deviceNotFound
    case connectionFailed(String)
    case captureSessionFailed(String)
    case pipNotAvailable
    case permissionDenied(String)
    case backgroundAudioFailed

    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "未检测到UVC设备，请检查硬件连接"
        case .connectionFailed(let reason):
            return "设备连接失败: \(reason)"
        case .captureSessionFailed(let reason):
            return "视频采集失败: \(reason)"
        case .pipNotAvailable:
            return "画中画功能不可用，请升级到 iPadOS 15+"
        case .permissionDenied(let type):
            return "权限被拒绝: \(type)"
        case .backgroundAudioFailed:
            return "后台音频启动失败"
        }
    }

    /// Maps the error to an ErrorLog.ErrorType for logging.
    var logErrorType: ErrorLog.ErrorType {
        switch self {
        case .deviceNotFound, .connectionFailed, .permissionDenied:
            return .deviceConnection
        case .captureSessionFailed:
            return .videoCapture
        case .pipNotAvailable:
            return .pipWindow
        case .backgroundAudioFailed:
            return .backgroundKeepAlive
        }
    }
}
