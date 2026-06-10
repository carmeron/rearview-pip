import Foundation
import Combine

/// Detects signal state from video frame metrics using a state machine
/// with sliding window debouncing to prevent rapid state flapping.
final class SignalStateDetector: ObservableObject {
    /// Published current signal state
    @Published private(set) var currentState: SignalState = .disconnected

    /// Callback invoked when state changes, passing old and new states
    var stateChangeHandler: ((SignalState, SignalState) -> Void)?

    /// Publisher that emits only state changes (not duplicate states)
    var stateDidChange: AnyPublisher<SignalState, Never> {
        $currentState
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// Current detection thresholds
    private var thresholds: DetectionThresholds = .default

    /// Sliding window of recent metrics for debouncing
    private var recentMetrics: [FrameMetrics] = []
    /// Window size for sliding average
    private let windowSize: Int = 5

    /// Serial queue for detection processing
    private let detectionQueue = DispatchQueue(label: "com.rearviewpip.detection", qos: .userInitiated)

    // MARK: - Public API

    /// Process a new frame metric and update state if needed.
    /// - Parameter metrics: The latest FrameMetrics
    func detectState(from metrics: FrameMetrics) {
        detectionQueue.async { [weak self] in
            guard let self = self else { return }

            // Maintain sliding window
            self.recentMetrics.append(metrics)
            if self.recentMetrics.count > self.windowSize {
                self.recentMetrics.removeFirst()
            }

            // Use sliding window averages to avoid jitter
            let avgBrightness: Float
            let avgContrast: Float
            let avgMotion: Float

            if self.recentMetrics.isEmpty {
                avgBrightness = metrics.brightness
                avgContrast = metrics.contrast
                avgMotion = metrics.motionMagnitude
            } else {
                avgBrightness = self.recentMetrics.map(\.brightness).reduce(0, +) / Float(self.recentMetrics.count)
                avgContrast = self.recentMetrics.map(\.contrast).reduce(0, +) / Float(self.recentMetrics.count)
                avgMotion = self.recentMetrics.map(\.motionMagnitude).reduce(0, +) / Float(self.recentMetrics.count)
            }

            let newState = self.determineState(
                brightness: avgBrightness,
                contrast: avgContrast,
                motion: avgMotion
            )

            if newState != self.currentState {
                let oldState = self.currentState
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.currentState = newState
                    self.stateChangeHandler?(oldState, newState)
                }
            }
        }
    }

    /// Update detection thresholds.
    /// - Parameter newThresholds: The new DetectionThresholds to use
    func setThresholds(_ newThresholds: DetectionThresholds) {
        detectionQueue.async { [weak self] in
            self?.thresholds = newThresholds
        }
    }

    /// Update thresholds based on a sensitivity level.
    /// - Parameter sensitivity: The desired sensitivity level
    func setSensitivity(_ sensitivity: Sensitivity) {
        setThresholds(.adjusted(for: sensitivity))
    }

    /// Reset the detector state and clear the sliding window.
    func reset() {
        detectionQueue.async { [weak self] in
            guard let self = self else { return }
            self.recentMetrics.removeAll()
            let oldState = self.currentState
            self.currentState = .disconnected
            DispatchQueue.main.async {
                self.stateChangeHandler?(oldState, .disconnected)
            }
        }
    }

    // MARK: - Private

    /// Determine the signal state from window-averaged metrics.
    private func determineState(brightness: Float, contrast: Float, motion: Float) -> SignalState {
        // Disconnected: very low brightness AND very low contrast
        if brightness < thresholds.brightnessDisconnected &&
           contrast < thresholds.contrastDisconnected {
            return .disconnected
        }

        // Active: high motion OR high brightness
        if motion > thresholds.motionActive ||
           brightness > thresholds.brightnessActive {
            return .active
        }

        // Default: device connected but no active signal
        return .idle
    }
}
