import Foundation
import AVFoundation
import Combine

/// Maintains background execution by playing a silent audio loop.
/// This is essential for keeping the PiP window alive when the app
/// is not in the foreground.
final class BackgroundAudioKeepAlive: ObservableObject {
    /// Published property indicating whether the keep-alive audio is active
    @Published private(set) var isActive: Bool = false

    private var audioPlayer: AVAudioPlayer?
    private var interruptionObserver: NSObjectProtocol?
    private let audioQueue = DispatchQueue(label: "com.rearviewpip.audiokeepalive", qos: .utility)

    // MARK: - Public API

    /// Start the silent audio playback to keep the app alive in the background.
    func startKeepAlive() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            // Configure audio session for background playback
            self.configureAudioSession()

            // Generate and play silent audio
            guard let player = self.createSilentAudioPlayer() else {
                DispatchQueue.main.async {
                    ErrorLogger.shared.log(
                        message: "Failed to create silent audio player",
                        type: .backgroundKeepAlive,
                        systemState: VideoStreamState(
                            signalState: .disconnected,
                            currentMetrics: nil,
                            deviceConnected: false,
                            frameRate: 0,
                            lastUpdateTime: Date()
                        )
                    )
                }
                return
            }

            player.numberOfLoops = -1  // Infinite loop
            player.volume = 0.0        // Silent
            player.prepareToPlay()

            let started = player.play()

            DispatchQueue.main.async {
                self.isActive = started
                self.audioPlayer = player
                #if DEBUG
                print("[BackgroundAudioKeepAlive] Keep-alive started: \(started)")
                #endif
            }

            // Start observing audio interruptions
            self.startInterruptionObserver()
        }
    }

    /// Stop the background keep-alive audio.
    func stopKeepAlive() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            self.audioPlayer?.stop()
            self.audioPlayer = nil
            self.stopInterruptionObserver()

            DispatchQueue.main.async {
                self.isActive = false
                #if DEBUG
                print("[BackgroundAudioKeepAlive] Keep-alive stopped")
                #endif
            }
        }
    }

    // MARK: - Private

    /// Configure AVAudioSession for background audio playback.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("[BackgroundAudioKeepAlive] Audio session config failed: \(error)")
            #endif
        }
    }

    /// Create an AVAudioPlayer with a programmatically generated silent WAV buffer.
    /// - Returns: Configured AVAudioPlayer, or nil if creation fails
    private func createSilentAudioPlayer() -> AVAudioPlayer? {
        // Generate a minimal silent WAV file in memory
        // WAV format: 44-byte header + silent PCM data
        let sampleRate: UInt32 = 44100
        let duration: Float = 1.0  // 1 second loop
        let numSamples = UInt32(Float(sampleRate) * duration)
        let dataSize = numSamples * 2  // 16-bit mono = 2 bytes per sample
        let fileSize: UInt32 = 44 + dataSize

        var wavData = Data()

        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: fileSize - 8, Array.init))
        wavData.append(contentsOf: "WAVE".utf8)

        // fmt subchunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16), Array.init))      // Subchunk1Size (16 for PCM)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1), Array.init))       // AudioFormat (1 = PCM)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1), Array.init))       // NumChannels (1 = mono)
        wavData.append(contentsOf: withUnsafeBytes(of: sampleRate, Array.init))       // SampleRate
        wavData.append(contentsOf: withUnsafeBytes(of: sampleRate * 2, Array.init))  // ByteRate
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(2), Array.init))       // BlockAlign
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(16), Array.init))      // BitsPerSample

        // data subchunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: dataSize, Array.init))

        // Silent PCM samples (all zeros)
        let silentSamples = Data(repeating: 0, count: Int(dataSize))
        wavData.append(silentSamples)

        // Write to temporary file (AVAudioPlayer requires a file URL)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("silent_keepalive.wav")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: tempURL)

        do {
            try wavData.write(to: tempURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[BackgroundAudioKeepAlive] Failed to write silent WAV: \(error)")
            #endif
            return nil
        }

        return try? AVAudioPlayer(contentsOf: tempURL)
    }

    // MARK: - Audio Interruption Handling

    private func startInterruptionObserver() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioInterruption(notification)
        }
    }

    private func stopInterruptionObserver() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
    }

    /// Handle audio session interruptions (e.g., phone calls, Siri).
    private func handleAudioInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Audio interrupted — player may have stopped
            #if DEBUG
            print("[BackgroundAudioKeepAlive] Audio interrupted")
            #endif

        case .ended:
            // Try to resume playback
            guard let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            if options.contains(.shouldResume) {
                audioQueue.async { [weak self] in
                    guard let self = self else { return }
                    let resumed = self.audioPlayer?.play() ?? false
                    DispatchQueue.main.async {
                        self.isActive = resumed
                    }
                    #if DEBUG
                    print("[BackgroundAudioKeepAlive] Audio resumed: \(resumed)")
                    #endif
                }
            }

        @unknown default:
            break
        }
    }

    deinit {
        stopKeepAlive()
    }
}
