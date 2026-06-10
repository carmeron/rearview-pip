import Foundation
import AVFoundation
import Combine

/// Manages UVC device discovery, connection, and disconnection.
final class DeviceManager: ObservableObject {
    /// Published property indicating whether a UVC device is currently connected
    @Published private(set) var isDeviceConnected: Bool = false

    /// The currently connected AVCaptureDevice, if any
    @Published private(set) var currentDevice: AVCaptureDevice?

    /// Callback invoked when device connection state changes
    var deviceConnectionHandler: ((Bool) -> Void)?

    /// Maximum number of reconnection attempts
    private let maxRetryCount = 5
    /// Delay between reconnection attempts in seconds
    private let retryDelay: TimeInterval = 3.0

    private var retryCount = 0
    private var retryWorkItem: DispatchWorkItem?
    private var deviceObservation: NSKeyValueObservation?
    private let scanQueue = DispatchQueue(label: "com.rearviewpip.devicemanager", qos: .userInitiated)

    // MARK: - Public API

    /// Scan for available UVC devices with a timeout.
    /// - Parameter timeout: Maximum time to wait for device discovery (seconds)
    /// - Returns: Array of available AVCaptureDevice instances
    func scanForUVCDevices(timeout: TimeInterval) async -> [AVCaptureDevice] {
        return await withCheckedContinuation { continuation in
            scanQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                let startTime = Date()
                var devices: [AVCaptureDevice] = []

                while Date().timeIntervalSince(startTime) < timeout {
                    devices = self.discoverUVCDevices()
                    if !devices.isEmpty { break }
                    Thread.sleep(forTimeInterval: 0.5)
                }

                continuation.resume(returning: devices)
            }
        }
    }

    /// Connect to the specified AVCaptureDevice.
    /// - Parameter device: The device to connect to
    func connect(to device: AVCaptureDevice) async throws {
        // Verify the device is still available
        guard AVCaptureDevice.devices().contains(device) else {
            throw RearViewPiPError.connectionFailed("设备不可用")
        }

        // Observe device disconnection
        deviceObservation = device.observe(\.isConnected, options: [.new, .old]) { [weak self] device, change in
            guard let self = self else { return }
            if !device.isConnected {
                self.handleDeviceDisconnect()
            }
        }

        await MainActor.run {
            self.currentDevice = device
            self.isDeviceConnected = true
            self.deviceConnectionHandler?(true)
            self.retryCount = 0
        }
    }

    /// Disconnect from the current device.
    func disconnect() {
        deviceObservation?.invalidate()
        deviceObservation = nil

        currentDevice = nil
        isDeviceConnected = false
        deviceConnectionHandler?(false)
        cancelRetry()
    }

    /// Begin automatic reconnection attempts.
    func startAutoReconnect() {
        guard retryCount < maxRetryCount else {
            #if DEBUG
            print("[DeviceManager] Max retry count (\(maxRetryCount)) reached, stopping auto-reconnect")
            #endif
            return
        }

        cancelRetry()

        retryCount += 1
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            #if DEBUG
            print("[DeviceManager] Auto-reconnect attempt \(self.retryCount)/\(self.maxRetryCount)")
            #endif

            let devices = self.discoverUVCDevices()
            if let firstDevice = devices.first {
                Task {
                    try? await self.connect(to: firstDevice)
                }
            } else if self.retryCount < self.maxRetryCount {
                self.startAutoReconnect()
            }
        }

        retryWorkItem = workItem
        scanQueue.asyncAfter(deadline: .now() + retryDelay, execute: workItem)
    }

    // MARK: - Private

    /// Discover available UVC (external) video capture devices.
    private func discoverUVCDevices() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .external
            ],
            mediaType: .video,
            position: .unspecified
        )

        // Filter for UVC-compliant devices (external USB video devices)
        return discoverySession.devices.filter { device in
            // External devices connected via USB/Lightning are typically UVC
            device.isConnected && device.hasMediaType(.video)
        }
    }

    /// Handle device disconnection observed via KVO.
    private func handleDeviceDisconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isDeviceConnected = false
            self.deviceConnectionHandler?(false)
            self.deviceObservation?.invalidate()
            self.deviceObservation = nil
            self.currentDevice = nil

            #if DEBUG
            print("[DeviceManager] Device disconnected, starting auto-reconnect")
            #endif
            self.startAutoReconnect()
        }
    }

    /// Cancel any pending retry work.
    private func cancelRetry() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
    }

    deinit {
        disconnect()
    }
}
