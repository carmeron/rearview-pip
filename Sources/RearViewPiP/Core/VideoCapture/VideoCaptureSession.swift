import Foundation
import AVFoundation
import Combine

/// Manages an AVCaptureSession for video input from a UVC device.
final class VideoCaptureSession: NSObject, ObservableObject {
    /// Published property indicating whether the session is running
    @Published private(set) var isRunning: Bool = false

    /// Callback delivering captured video frames as CVPixelBuffer with timestamp
    var frameOutputHandler: ((CVPixelBuffer, CMTime) -> Void)?

    /// The underlying AVCaptureSession
    private let captureSession = AVCaptureSession()
    /// Serial queue for video data output
    private let videoOutputQueue = DispatchQueue(label: "com.rearviewpip.videooutput", qos: .userInitiated)
    /// Video data output
    private let videoOutput = AVCaptureVideoDataOutput()
    /// Current target frame rate
    private var targetFrameRate: Int = 30

    // MARK: - Public API

    /// Start video capture from the given device.
    /// - Parameter device: The AVCaptureDevice to capture from
    func startCapture(with device: AVCaptureDevice) throws {
        guard !captureSession.isRunning else { return }

        captureSession.beginConfiguration()

        // Remove any existing inputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }

        // Add device input
        let deviceInput: AVCaptureDeviceInput
        do {
            deviceInput = try AVCaptureDeviceInput(device: device)
        } catch {
            captureSession.commitConfiguration()
            throw RearViewPiPError.captureSessionFailed("无法创建设备输入: \(error.localizedDescription)")
        }

        guard captureSession.canAddInput(deviceInput) else {
            captureSession.commitConfiguration()
            throw RearViewPiPError.captureSessionFailed("无法添加设备输入到会话")
        }
        captureSession.addInput(deviceInput)

        // Configure video output
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)

        if captureSession.outputs.isEmpty {
            guard captureSession.canAddOutput(videoOutput) else {
                captureSession.commitConfiguration()
                throw RearViewPiPError.captureSessionFailed("无法添加视频输出到会话")
            }
            captureSession.addOutput(videoOutput)
        }

        // Set initial frame rate
        setDeviceFrameRate(device, fps: targetFrameRate)

        captureSession.commitConfiguration()

        // Start running on a background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
            }
        }
    }

    /// Stop video capture.
    func stopCapture() {
        guard captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
    }

    /// Set the target frame rate for capture.
    /// - Parameter fps: Desired frames per second (1-30)
    func setFrameRate(_ fps: Int) {
        let clamped = min(max(fps, 1), 30)
        targetFrameRate = clamped

        guard let device = captureSession.inputs
            .compactMap({ ($0 as? AVCaptureDeviceInput)?.device })
            .first else { return }

        setDeviceFrameRate(device, fps: clamped)
    }

    /// Configure the capture session preset for given resolution.
    func setResolution(width: Int32, height: Int32) {
        captureSession.beginConfiguration()
        // Use a standard preset as base, specific resolution set via device formats
        if width <= 640 {
            captureSession.sessionPreset = .vga640x480
        } else if width <= 1280 {
            captureSession.sessionPreset = .hd1280x720
        } else {
            captureSession.sessionPreset = .hd1920x1080
        }
        captureSession.commitConfiguration()
    }

    // MARK: - Private

    /// Set the frame rate on an AVCaptureDevice.
    private func setDeviceFrameRate(_ device: AVCaptureDevice, fps: Int) {
        do {
            try device.lockForConfiguration()

            if let format = device.activeFormat,
               let _ = format.videoSupportedFrameRateRanges.first {
                // Find the best matching frame rate range
                for range in format.videoSupportedFrameRateRanges {
                    if Int(range.maxFrameRate) >= fps {
                        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                        break
                    }
                }
            }

            device.unlockForConfiguration()
        } catch {
            #if DEBUG
            print("[VideoCaptureSession] Failed to set frame rate: \(error)")
            #endif
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VideoCaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        autoreleasepool {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            frameOutputHandler?(pixelBuffer, timestamp)
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        #if DEBUG
        print("[VideoCaptureSession] Frame dropped")
        #endif
    }
}
