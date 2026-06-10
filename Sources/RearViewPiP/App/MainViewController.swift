import UIKit
import AVFoundation
import Combine

/// The main view controller that orchestrates all components:
/// device management, video capture, frame analysis, signal detection,
/// PiP control, and content rendering.
final class MainViewController: UIViewController {
    // MARK: - Core Components

    private let deviceManager = DeviceManager()
    private let captureSession = VideoCaptureSession()
    private let frameAnalyzer = VideoFrameAnalyzer()
    private let signalDetector = SignalStateDetector()
    private let backgroundAudio = BackgroundAudioKeepAlive()
    private let thermalManager = ThermalManager()

    private lazy var pipController: PiPWindowController = {
        PiPWindowController(
            signalDetector: signalDetector,
            backgroundAudio: backgroundAudio
        )
    }()

    // MARK: - State

    private var cancellables = Set<AnyCancellable>()
    private var lastFrame: CVPixelBuffer?
    private var currentFrameRate: Int = 1  // Start at 1fps (idle/disconnected)

    // MARK: - UI Elements

    private let statusLabel = UILabel()
    private let previewView = UIView()
    private let settingsButton = UIButton(type: .system)
    private let pipButton = UIButton(type: .system)
    private let stateIndicator = UIView()

    // Sample buffer display layer for preview
    private var previewDisplayLayer: AVSampleBufferDisplayLayer?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
        checkFirstLaunch()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startVideoPipeline()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Don't stop capture if PiP is active
        if !pipController.isPiPActive {
            captureSession.stopCapture()
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .black
        title = "RearViewPiP"

        // Preview view — fills the entire background
        previewView.backgroundColor = .black
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)

        // Status label — overlay at top
        statusLabel.text = "正在初始化..."
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        // State indicator — colored dot
        stateIndicator.backgroundColor = .yellow
        stateIndicator.layer.cornerRadius = 8
        stateIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stateIndicator)

        // PiP button
        pipButton.setTitle("进入画中画", for: .normal)
        pipButton.setTitleColor(.white, for: .normal)
        pipButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        pipButton.backgroundColor = .systemBlue
        pipButton.layer.cornerRadius = 10
        pipButton.translatesAutoresizingMaskIntoConstraints = false
        pipButton.addTarget(self, action: #selector(pipButtonTapped), for: .touchUpInside)
        view.addSubview(pipButton)

        // Settings button
        settingsButton.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
        settingsButton.tintColor = .white
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        view.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            statusLabel.heightAnchor.constraint(equalToConstant: 32),

            stateIndicator.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 8),
            stateIndicator.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            stateIndicator.widthAnchor.constraint(equalToConstant: 16),
            stateIndicator.heightAnchor.constraint(equalToConstant: 16),

            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),

            pipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pipButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            pipButton.widthAnchor.constraint(equalToConstant: 160),
            pipButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Observers

    private func setupObservers() {
        // Signal state changes
        signalDetector.stateDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)

        // Device connection changes
        deviceManager.$isDeviceConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.handleDeviceConnectionChange(connected)
            }
            .store(in: &cancellables)

        // Thermal state changes
        thermalManager.$recommendedFrameRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fps in
                self?.adjustFrameRate(fps)
            }
            .store(in: &cancellables)

        // Memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // MARK: - Video Pipeline

    private func startVideoPipeline() {
        Task {
            // Scan for UVC devices
            let devices = await deviceManager.scanForUVCDevices(timeout: 3.0)

            if let device = devices.first {
                do {
                    try await deviceManager.connect(to: device)

                    // Start capture
                    try captureSession.startCapture(with: device)

                    // Set initial frame rate (1fps for idle)
                    captureSession.setFrameRate(currentFrameRate)

                    // Set up frame handling
                    captureSession.frameOutputHandler = { [weak self] pixelBuffer, timestamp in
                        self?.processVideoFrame(pixelBuffer, timestamp: timestamp)
                    }

                    // Start thermal monitoring
                    thermalManager.startMonitoring()

                    await MainActor.run {
                        statusLabel.text = "设备已连接"
                    }
                } catch {
                    await MainActor.run {
                        statusLabel.text = "连接失败: \(error.localizedDescription)"
                        deviceManager.startAutoReconnect()
                    }
                }
            } else {
                await MainActor.run {
                    statusLabel.text = "未检测到设备 — 正在搜索..."
                }
                deviceManager.startAutoReconnect()
            }
        }
    }

    /// Process a single video frame through the analysis pipeline.
    private func processVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        autoreleasepool {
            let metrics = frameAnalyzer.analyze(
                pixelBuffer: pixelBuffer,
                previousPixelBuffer: lastFrame
            )

            // Create metrics with actual timestamp
            let timedMetrics = FrameMetrics(
                brightness: metrics.brightness,
                contrast: metrics.contrast,
                motionMagnitude: metrics.motionMagnitude,
                timestamp: timestamp
            )

            // Feed into signal detector
            signalDetector.detectState(from: timedMetrics)

            // Update PiP content if in active state
            let currentState = signalDetector.currentState
            if currentState == .active {
                DispatchQueue.main.async { [weak self] in
                    self?.pipController.updateContent(with: pixelBuffer)
                }
            }

            // Update preview
            enqueuePreviewFrame(pixelBuffer)

            // Store for next frame comparison
            lastFrame = pixelBuffer
        }
    }

    private func enqueuePreviewFrame(_ pixelBuffer: CVPixelBuffer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.previewDisplayLayer == nil {
                let layer = AVSampleBufferDisplayLayer()
                layer.videoGravity = .resizeAspect
                layer.frame = self.previewView.bounds
                self.previewView.layer.addSublayer(layer)
                self.previewDisplayLayer = layer
            }

            guard let displayLayer = self.previewDisplayLayer,
                  displayLayer.isReadyForMoreMediaData else { return }

            var sampleBuffer: CMSampleBuffer?
            var timingInfo = CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: CMTimeScale(currentFrameRate)),
                presentationTimeStamp: CMTime.seconds(CACurrentMediaTime()),
                decodeTimeStamp: .invalid
            )

            var formatDesc: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescriptionOut: &formatDesc
            )

            guard let formatDesc = formatDesc else { return }

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
    }

    // MARK: - State Handling

    private func handleStateChange(_ state: SignalState) {
        statusLabel.text = state.displayName

        // Update frame rate based on state
        switch state {
        case .active:
            currentFrameRate = thermalManager.recommendedFrameRate  // 30fps nominal
            stateIndicator.backgroundColor = .red
        case .idle:
            currentFrameRate = 1
            stateIndicator.backgroundColor = .green
        case .disconnected:
            currentFrameRate = 1
            stateIndicator.backgroundColor = .yellow
        }

        captureSession.setFrameRate(currentFrameRate)

        // Update PiP content
        pipController.updateContent(with: lastFrame)

        // Update status label
        switch state {
        case .active:
            statusLabel.text = "倒车中 — \(currentFrameRate) fps"
        case .idle:
            statusLabel.text = "待命中"
        case .disconnected:
            statusLabel.text = "设备未连接"
        }
    }

    private func handleDeviceConnectionChange(_ connected: Bool) {
        if connected {
            statusLabel.text = "设备已连接"
            stateIndicator.backgroundColor = .green
        } else {
            statusLabel.text = "设备未连接 — 正在重试..."
            stateIndicator.backgroundColor = .yellow
        }
    }

    private func adjustFrameRate(_ fps: Int) {
        currentFrameRate = signalDetector.currentState == .active ? fps : 1
        captureSession.setFrameRate(currentFrameRate)
        statusLabel.text = "\(signalDetector.currentState.displayName) — \(currentFrameRate) fps"
    }

    // MARK: - First Launch

    private func checkFirstLaunch() {
        let config = ConfigurationManager.shared.loadConfiguration()
        if !config.setupCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.presentSetupWizard()
            }
        }
    }

    private func presentSetupWizard() {
        let wizard = SetupWizardViewController()
        wizard.onSetupCompleted = { [weak self] in
            self?.startVideoPipeline()
        }
        let nav = UINavigationController(rootViewController: wizard)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: - Actions

    @objc private func pipButtonTapped() {
        if pipController.isPiPActive {
            pipController.stopPiP()
            pipButton.setTitle("进入画中画", for: .normal)
        } else {
            do {
                try pipController.startPiP(from: self)
                pipButton.setTitle("退出画中画", for: .normal)
            } catch {
                let alert = UIAlertController(
                    title: "画中画不可用",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                present(alert, animated: true)
            }
        }
    }

    @objc private func settingsButtonTapped() {
        let settingsVC = SettingsViewController()
        let nav = UINavigationController(rootViewController: settingsVC)
        present(nav, animated: true)
    }

    @objc private func handleMemoryWarning() {
        lastFrame = nil
        PixelBufferPool().clear()
        captureSession.setFrameRate(max(1, currentFrameRate / 2))

        #if DEBUG
        print("[MainViewController] Memory warning received — frame rate reduced")
        #endif
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
        captureSession.stopCapture()
        backgroundAudio.stopKeepAlive()
        thermalManager.stopMonitoring()
    }
}
