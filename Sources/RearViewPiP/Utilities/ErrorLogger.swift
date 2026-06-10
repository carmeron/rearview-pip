import Foundation

/// Logs errors to a rotating file on disk for diagnostics.
final class ErrorLogger {
    static let shared = ErrorLogger()

    private let logFileURL: URL
    private let maxLogSize: Int = 5 * 1024 * 1024  // 5MB
    private let queue = DispatchQueue(label: "com.rearviewpip.errorlogger", qos: .utility)
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private init() {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let logsDir = documentsPath.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        self.logFileURL = logsDir.appendingPathComponent("errors.json")
    }

    /// Log an error with the current system state.
    func log(_ error: RearViewPiPError, systemState: VideoStreamState) {
        let errorLog = ErrorLog(
            timestamp: Date(),
            errorType: error.logErrorType,
            message: error.localizedDescription,
            systemState: systemState.description
        )

        queue.async { [weak self] in
            self?.appendToLogFile(errorLog)
        }
    }

    /// Log a generic message with error type (for non-RearViewPiPError errors).
    func log(message: String, type: ErrorLog.ErrorType, systemState: VideoStreamState) {
        let errorLog = ErrorLog(
            timestamp: Date(),
            errorType: type,
            message: message,
            systemState: systemState.description
        )

        queue.async { [weak self] in
            self?.appendToLogFile(errorLog)
        }
    }

    /// Read all logged errors.
    func readLogs() -> [ErrorLog] {
        guard let data = try? Data(contentsOf: logFileURL),
              let logs = try? JSONDecoder().decode([ErrorLog].self, from: data) else {
            return []
        }
        return logs
    }

    /// Clear all stored logs.
    func clearLogs() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.logFileURL)
        }
    }

    // MARK: - Private

    private func appendToLogFile(_ log: ErrorLog) {
        var existingLogs: [ErrorLog] = []

        if let data = try? Data(contentsOf: logFileURL),
           let logs = try? JSONDecoder().decode([ErrorLog].self, from: data) {
            existingLogs = logs
        }

        existingLogs.append(log)

        // Rotate if exceeds max size (keep last 75% of entries)
        if let encoded = try? encoder.encode(existingLogs), encoded.count > maxLogSize {
            let keepCount = Int(Double(existingLogs.count) * 0.75)
            existingLogs = Array(existingLogs.suffix(max(keepCount, 1)))
        }

        if let encoded = try? encoder.encode(existingLogs) {
            try? encoded.write(to: logFileURL, options: .atomic)
        }
    }
}
