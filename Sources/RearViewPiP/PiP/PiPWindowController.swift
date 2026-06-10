import Foundation
import UIKit
import AVKit
import Combine

/// Manages the Picture-in-Picture window lifecycle and content switching.
/// This is the central coordinator for the PiP experience.
final class PiPWindowController: NSObject, ObservableObject {
    /// Published property indicating whether PiP mode is currently active
    @Published private(set) var isPiPActive: Bool = false

    /// The system PiP controller
    private var pipController: AVPictureInPictureController?

    /// The content renderer
    private let contentRenderer = ContentRenderer()

    /// The source view that provides video content for PiP
    private var sourceView: UIView?

    /// The view controller hosting the PiP source view
    private weak var presentingViewController: UIViewController?

    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()

    /// Signal state observation
    private let signalDetector: SignalStateDetector
    private let backgroundAudio: BackgroundAudioKeepAlive

    // MARK: - Initialization

    /// Initialize the PiP window controller.
    /// - Parameters:
    ///   - signalDetector: The signal state detector to observe
    ///   - backgroundAudio: The background audio keep-alive instance
    init(signalDetector: SignalStateDetector,
         backgroundAudio: BackgroundAudioKeepAlive) {
        self.signalDetector = signalDetector
        self.backgroundAudio = backgroundAudio
        super.init()
        setupStateObservation()
    }

    // MARK: - Public API

    /// Start Picture-in-Picture mode.
    /// - Parameter viewController: The presenting view controller
    func startPiP(from viewController: UIViewController) throws {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            throw RearViewPiPError.pipNotAvailable
        }

        self.presentingViewController = viewController

        // Create a source view for PiP content
        let pipSourceView = UIView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        pipSourceView.backgroundColor = .black
        self.sourceView = pipSourceView

        // Create a wrapper view controller required by AVPictureInPictureController
        let pipContentVC = UIViewController()
        pipContentVC.view.addSubview(pipSourceView)
        pipSourceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pipSourceView.topAnchor.constraint(equalTo: pipContentVC.view.topAnchor),
            pipSourceView.leadingAnchor.constraint(equalTo: pipContentVC.view.leadingAnchor),
            pipSourceView.trailingAnchor.constraint(equalTo: pipContentVC.view.trailingAnchor),
            pipSourceView.bottomAnchor.constraint(equalTo: pipContentVC.view.bottomAnchor)
        ])

        // Create AVPlayerLayer for video rendering (required for PiP)
        let player = AVPlayer(url: URL(fileURLWithPath: ""))  // Placeholder player
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = pipSourceView.bounds
        pipSourceView.layer.addSublayer(playerLayer)

        // Initialize PiP controller with the player layer
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self

        // Start PiP if possible
        if pipController?.isPictureInPicturePossible == true {
            pipController?.startPictureInPicture()
        }

        // Start background audio to keep PiP alive
        backgroundAudio.startKeepAlive()

        #if DEBUG
        print("[PiPWindowController] PiP started")
        #endif
    }

    /// Stop Picture-in-Picture mode.
    func stopPiP() {
        pipController?.stopPictureInPicture()
        pipController = nil
        backgroundAudio.stopKeepAlive()
        isPiPActive = false

        #if DEBUG
        print("[PiPWindowController] PiP stopped")
        #endif
    }

    /// Update the PiP window content based on current signal state.
    /// - Parameter pixelBuffer: Optional video frame for active state
    func updateContent(with pixelBuffer: CVPixelBuffer?) {
        guard let sourceView = sourceView else { return }

        let state = signalDetector.currentState
        contentRenderer.updatePiPContent(
            state: state,
            pixelBuffer: pixelBuffer,
            targetView: sourceView
        )
    }

    /// Enter fullscreen mode from PiP.
    func enterFullscreen() {
        guard let presentingVC = presentingViewController,
              let pipVC = pipController?.value(forKey: "pictureInPictureViewController") as? UIViewController else {
            return
        }

        // Dismiss PiP and present fullscreen
        pipController?.stopPictureInPicture()
        pipVC.modalPresentationStyle = .fullScreen
        presentingVC.present(pipVC, animated: true)
    }

    /// Exit fullscreen and return to PiP mode.
    func exitFullscreen() {
        presentingViewController?.dismiss(animated: true) { [weak self] in
            self?.pipController?.startPictureInPicture()
        }
    }

    /// Save the current PiP window position preferences.
    func saveWindowPreferences() {
        guard let sourceView = sourceView else { return }
        ConfigurationManager.shared.savePiPWindowFrame(sourceView.frame)
    }

    // MARK: - Private

    /// Observe signal state changes and update PiP content accordingly.
    private func setupStateObservation() {
        signalDetector.stateDidChange
            .sink { [weak self] state in
                guard let self = self else { return }
                #if DEBUG
                print("[PiPWindowController] Signal state changed: \(state.rawValue)")
                #endif
                self.updateContent(with: nil)
            }
            .store(in: &cancellables)

        // Observe configuration changes that affect rendering
        ConfigurationManager.shared.configurationDidChange
            .sink { [weak self] _ in
                self?.updateContent(with: nil)
            }
            .store(in: &cancellables)
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PiPWindowController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        isPiPActive = true
        #if DEBUG
        print("[PiPWindowController] PiP did start")
        #endif
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        isPiPActive = false
        #if DEBUG
        print("[PiPWindowController] PiP did stop")
        #endif
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        isPiPActive = false
        ErrorLogger.shared.log(
            message: "PiP启动失败: \(error.localizedDescription)",
            type: .pipWindow,
            systemState: VideoStreamState(
                signalState: signalDetector.currentState,
                currentMetrics: nil,
                deviceConnected: false,
                frameRate: 0,
                lastUpdateTime: Date()
            )
        )
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // Restore the app when user taps the PiP window
        if let presentingVC = presentingViewController {
            presentingVC.view.isHidden = false
        }
        completionHandler(true)
    }

    func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        #if DEBUG
        print("[PiPWindowController] PiP will start")
        #endif
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ controller: AVPictureInPictureController) {
        #if DEBUG
        print("[PiPWindowController] PiP will stop")
        #endif
    }
}
