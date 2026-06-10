import Foundation

/// Runtime performance metrics for monitoring and thermal adaptation.
struct PerformanceMetrics {
    /// CPU usage percentage [0-100]
    var cpuUsage: Float
    /// GPU usage percentage [0-100]
    var gpuUsage: Float
    /// Current memory footprint in bytes
    var memoryUsage: UInt64
    /// Device thermal state
    var thermalState: ProcessInfo.ThermalState
    /// End-to-end frame latency in seconds
    var frameLatency: TimeInterval

    /// Whether current resource usage is within acceptable limits
    var isWithinLimits: Bool {
        cpuUsage < 15.0
            && gpuUsage < 20.0
            && memoryUsage < 150 * 1024 * 1024
            && thermalState != .critical
    }

    /// Optimal frame rate given the current thermal state
    var recommendedFrameRate: Int {
        switch thermalState {
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
}
