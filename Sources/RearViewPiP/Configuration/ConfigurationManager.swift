import Foundation
import Combine

/// Manages application configuration persistence via UserDefaults.
final class ConfigurationManager: ObservableObject {
    /// Shared singleton instance
    static let shared = ConfigurationManager()

    /// Current application configuration
    @Published private(set) var configuration: AppConfiguration {
        didSet {
            saveToDisk()
        }
    }

    /// Publisher that emits the full configuration on any change
    var configurationDidChange: AnyPublisher<AppConfiguration, Never> {
        $configuration.eraseToAnyPublisher()
    }

    /// Publisher that emits only guide line style changes
    var guideLineStyleDidChange: AnyPublisher<GuideLineStyle, Never> {
        $configuration
            .map(\.guideLineStyle)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// Publisher that emits only sensitivity changes
    var sensitivityDidChange: AnyPublisher<Sensitivity, Never> {
        $configuration
            .map(\.detectionSensitivity)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private let defaults: UserDefaults
    private let configKey = "com.rearviewpip.configuration"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.configuration = Self.loadFromDisk(defaults: defaults, key: configKey) ?? .default
    }

    // MARK: - Public API

    /// Load the current configuration.
    func loadConfiguration() -> AppConfiguration {
        return configuration
    }

    /// Save a new configuration.
    func saveConfiguration(_ config: AppConfiguration) throws {
        let data = try encoder.encode(config)
        defaults.set(data, forKey: configKey)
        configuration = config
    }

    /// Reset configuration to defaults.
    func resetToDefaults() {
        configuration = .default
    }

    /// Update guide line style.
    func setGuideLineStyle(_ style: GuideLineStyle) {
        var config = configuration
        config.guideLineStyle = style
        configuration = config
    }

    /// Update detection sensitivity.
    func setSensitivity(_ sensitivity: Sensitivity) {
        var config = configuration
        config.detectionSensitivity = sensitivity
        configuration = config
    }

    /// Toggle visual alerts.
    func setVisualAlertsEnabled(_ enabled: Bool) {
        var config = configuration
        config.visualAlertsEnabled = enabled
        configuration = config
    }

    /// Save PiP window position.
    func savePiPWindowFrame(_ frame: CGRect) {
        var config = configuration
        config.pipWindowFrame = frame
        configuration = config
    }

    /// Mark setup wizard as completed.
    func markSetupCompleted() {
        var config = configuration
        config.setupCompleted = true
        configuration = config
    }

    // MARK: - Private

    private func saveToDisk() {
        guard let data = try? encoder.encode(configuration) else { return }
        defaults.set(data, forKey: configKey)
    }

    private static func loadFromDisk(defaults: UserDefaults, key: String) -> AppConfiguration? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AppConfiguration.self, from: data)
    }
}
