import Foundation
import UIKit
import CoreVideo
import AVFoundation

/// Renders content for the PiP window based on the current signal state.
final class ContentRenderer {
    /// The guide line renderer for parking overlay
    private let guideLineRenderer = GuideLineRenderer()

    /// PiP sample buffer layer for video rendering
    private var displayLayer: AVSampleBufferDisplayLayer?

    /// CIContext for efficient image processing
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .highQualityDownsample: true
    ])

    /// Current frame size for layout calculations
    private var currentFrameSize: CGSize = .zero

    /// Whether the red border flash is currently on (for active state alert)
    private var borderFlashOn: Bool = false
    private var flashTimer: Timer?

    // MARK: - Public API

    /// Render content for the given signal state.
    /// - Parameters:
    ///   - state: Current signal state
    ///   - videoFrame: Optional video frame for active state
    ///   - guideLineStyle: Optional guide line style for overlay
    /// - Returns: A CALayer tree ready for display
    func render(for state: SignalState,
                videoFrame: CVPixelBuffer?,
                guideLineStyle: GuideLineStyle?) -> CALayer {
        let containerLayer = CALayer()

        switch state {
        case .active:
            return renderActiveVideo(videoFrame, withGuidelines: guideLineStyle ?? .standard)

        case .idle:
            return renderIdleLogo()

        case .disconnected:
            return renderError(message: "设备未连接\n请检查硬件连接")
        }
    }

    /// Render the standby/logo view.
    func renderIdleLogo() -> CALayer {
        stopFlashTimer()

        let containerLayer = CALayer()

        // Background — semi-transparent dark
        let bgLayer = CALayer()
        bgLayer.backgroundColor = UIColor.black.withAlphaComponent(0.3).cgColor
        containerLayer.addSublayer(bgLayer)

        // Logo text layer
        let textLayer = CATextLayer()
        textLayer.string = "RearViewPiP"
        textLayer.fontSize = 28
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Light" as CFString, 28, nil)
        textLayer.foregroundColor = UIColor.white.withAlphaComponent(0.5).cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = UIScreen.main.scale
        containerLayer.addSublayer(textLayer)

        // Subtitle
        let subtitleLayer = CATextLayer()
        subtitleLayer.string = "待命中..."
        subtitleLayer.fontSize = 14
        subtitleLayer.font = CTFontCreateWithName("HelveticaNeue-Light" as CFString, 14, nil)
        subtitleLayer.foregroundColor = UIColor.white.withAlphaComponent(0.3).cgColor
        subtitleLayer.alignmentMode = .center
        subtitleLayer.contentsScale = UIScreen.main.scale
        containerLayer.addSublayer(subtitleLayer)

        return containerLayer
    }

    /// Render active video with guide line overlay.
    func renderActiveVideo(_ pixelBuffer: CVPixelBuffer?,
                           withGuidelines style: GuideLineStyle) -> CALayer {
        let containerLayer = CALayer()

        guard let pixelBuffer = pixelBuffer else {
            return renderError(message: "视频信号异常")
        }

        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        currentFrameSize = CGSize(width: frameWidth, height: frameHeight)

        // Video layer
        let videoImage = CIImage(cvPixelBuffer: pixelBuffer)
        let videoLayer = CALayer()

        // Render CIImage to CGImage for CALayer contents
        if let cgImage = ciContext.createCGImage(videoImage, from: videoImage.extent) {
            videoLayer.contents = cgImage
            videoLayer.contentsGravity = .resizeAspect
        }

        containerLayer.addSublayer(videoLayer)

        // Guide line overlay
        let guideLayer = guideLineRenderer.createGuideLines(
            style: style,
            frameSize: currentFrameSize
        )
        containerLayer.addSublayer(guideLayer)

        // Start red border flash if visual alerts enabled
        let config = ConfigurationManager.shared.loadConfiguration()
        if config.visualAlertsEnabled {
            startBorderFlash(on: containerLayer)
        }

        return containerLayer
    }

    /// Render error/disconnected state.
    func renderError(message: String) -> CALayer {
        stopFlashTimer()

        let containerLayer = CALayer()

        // Background — dark with slight transparency
        let bgLayer = CALayer()
        bgLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
        containerLayer.addSublayer(bgLayer)

        // Yellow border for error state
        containerLayer.borderColor = UIColor.yellow.cgColor
        containerLayer.borderWidth = 3.0

        // Error icon (⚠️ represented as text)
        let iconLayer = CATextLayer()
        iconLayer.string = "⚠️"
        iconLayer.fontSize = 36
        iconLayer.alignmentMode = .center
        iconLayer.contentsScale = UIScreen.main.scale
        containerLayer.addSublayer(iconLayer)

        // Error message
        let textLayer = CATextLayer()
        textLayer.string = message
        textLayer.fontSize = 16
        textLayer.font = CTFontCreateWithName("HelveticaNeue" as CFString, 16, nil)
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.isWrapped = true
        containerLayer.addSublayer(textLayer)

        return containerLayer
    }

    /// Create a sample buffer display layer for AVSampleBufferDisplayLayer-based rendering.
    func createDisplayLayer() -> AVSampleBufferDisplayLayer {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspect
        displayLayer = layer
        return layer
    }

    /// Enqueue a pixel buffer to the display layer.
    func enqueuePixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        guard let displayLayer = displayLayer, displayLayer.isReadyForMoreMediaData else {
            return
        }

        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime.seconds(CACurrentMediaTime()),
            decodeTimeStamp: .invalid
        )

        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )

        guard let formatDesc = formatDescription else { return }

        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        if let buffer = sampleBuffer {
            displayLayer.enqueue(buffer)
        }
    }

    /// Flush any queued buffers in the display layer.
    func flushDisplayLayer() {
        displayLayer?.flush()
    }

    /// Update content on an existing PiP view controller's source view.
    /// - Parameters:
    ///   - state: Current signal state
    ///   - pixelBuffer: Optional video frame
    ///   - targetView: The view to update
    func updatePiPContent(state: SignalState,
                          pixelBuffer: CVPixelBuffer?,
                          targetView: UIView) {
        let config = ConfigurationManager.shared.loadConfiguration()
        targetView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let contentLayer = render(
            for: state,
            videoFrame: pixelBuffer,
            guideLineStyle: config.guideLineStyle
        )
        contentLayer.frame = targetView.bounds
        targetView.layer.addSublayer(contentLayer)
    }

    // MARK: - Private

    /// Start the red border flash animation for active (reversing) state.
    private func startBorderFlash(on layer: CALayer) {
        stopFlashTimer()

        layer.borderColor = UIColor.red.cgColor
        layer.borderWidth = 3.0

        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak layer] timer in
            guard let layer = layer else {
                timer.invalidate()
                return
            }
            self.borderFlashOn.toggle()
            layer.borderWidth = self.borderFlashOn ? 3.0 : 1.0
            layer.borderColor = self.borderFlashOn
                ? UIColor.red.cgColor
                : UIColor.red.withAlphaComponent(0.4).cgColor
        }

        // Ensure timer runs even during scroll tracking
        if let timer = flashTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// Stop the border flash timer.
    private func stopFlashTimer() {
        flashTimer?.invalidate()
        flashTimer = nil
        borderFlashOn = false
    }

    deinit {
        stopFlashTimer()
    }
}
