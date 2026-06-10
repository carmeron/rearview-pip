import Foundation
import Combine

/// Monitors device thermal state and publishes adaptive frame rate recommendations.
final class ThermalManager: ObservableObject {
    /// Published recommended frame rate based on current thermal state
    @Published private(set) var recommendedFrameRate: Int = 30

    /// Published thermal state for UI display
    @Published private(set) var currentThermalState: ProcessInfo.ThermalState = .nominal

    private var thermalStateObserver: NSObjectProtocol?
    private let processInfo: ProcessInfo

    init(processInfo: ProcessInfo = .processInfo) {
        self.processInfo = processInfo
        self.currentThermalState = processInfo.thermalState
        self.recommendedFrameRate = Self.frameRate(for: processInfo.thermalState)
    }

    /// Begin monitoring thermal state changes.
    func startMonitoring() {
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleThermalStateChange()
        }
    }

    /// Stop monitoring thermal state changes.
    func stopMonitoring() {
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
            thermalStateObserver = nil
        }
    }

    /// Returns the recommended frame rate for a given thermal state.
    static func frameRate(for state: ProcessInfo.ThermalState) -> Int {
        switch state {
        case .nominal:
            return 30
        case .fair:
            return 30
        case .serious:
            return 15
        case .critical:
            return 10
        @unknown default:
            return 20
        }
    }

    /// Whether the device is currently overheating.
    var isThermallyThrottled: Bool {
        currentThermalState == .serious || currentThermalState == .critical
    }

    // MARK: - Private

    private func handleThermalStateChange() {
        let state = processInfo.thermalState
        currentThermalState = state
        recommendedFrameRate = Self.frameRate(for: state)

        #if DEBUG
        print("[ThermalManager] State changed to \(state.rawValue), recommended FPS: \(recommendedFrameRate)")
        #endif
    }

    deinit {
        stopMonitoring()
    }
}
