import Foundation
import Darwin

/// Reads quotas through Codex's documented local app-server interface.
/// Each poll owns a short-lived child, avoiding an idle server's memory cost.
actor AppServerProvider: UsageProvider {
    enum ProviderError: Error {
        case cliMissing, launchFailed, timedOut, disconnected, malformedResponse
        case requestRejected, notSignedIn
    }

    private let executableOverride: URL?
    private let timeout: Duration

    init(executable: URL? = nil, timeout: Duration = .seconds(20)) {
        self.executableOverride = executable
        self.timeout = timeout
    }

    private var pending: Task<UsageSnapshot, Error>?

    func fetchUsage() async throws -> UsageSnapshot {
        if let pending { return try await pending.value }
        let executable = executableOverride
        let timeout = timeout
        let task = Task(priority: .background) { try await Self.fetch(executable: executable, timeout: timeout) }
        pending = task
        defer { pending = nil }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func executable() throws -> URL {
        let home = NSHomeDirectory()
        let directories = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
            + ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin", "\(home)/.cargo/bin"]
        for directory in directories {
            let url = URL(fileURLWithPath: directory).appendingPathComponent("codex")
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }
        throw ProviderError.cliMissing
    }

    private static func fetch(executable: URL?, timeout: Duration) async throws -> UsageSnapshot {
        let process = Process()
        process.qualityOfService = .background
        process.executableURL = try executable ?? Self.executable()
        process.arguments = ["app-server", "--stdio", "-c", "analytics.enabled=false"]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        // Server diagnostics can contain account information.
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw ProviderError.launchFailed }
        defer {
            try? input.fileHandleForWriting.close()
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            try? output.fileHandleForReading.close()
        }
        let descriptor = output.fileHandleForReading.fileDescriptor
        guard fcntl(descriptor, F_SETFL, O_NONBLOCK) != -1 else {
            throw ProviderError.launchFailed
        }
        var buffer = Data()
        let deadline = ContinuousClock.now.advanced(by: timeout)

        func send(_ message: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: message)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        func response(id: Int) async throws -> Data {
            while true {
                try Task.checkCancellation()
                guard ContinuousClock.now < deadline else { throw ProviderError.timedOut }
                while let newline = buffer.firstIndex(of: 10) {
                    let line = buffer.prefix(upTo: newline)
                    buffer.removeSubrange(...newline)
                    guard let message = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                        throw ProviderError.malformedResponse
                    }
                    guard message["id"] as? Int == id else { continue }
                    guard message["error"] == nil else { throw ProviderError.requestRejected }
                    guard let result = message["result"] as? [String: Any] else {
                        throw ProviderError.malformedResponse
                    }
                    return try JSONSerialization.data(withJSONObject: result)
                }
                var bytes = [UInt8](repeating: 0, count: 8192)
                let count = Darwin.read(descriptor, &bytes, bytes.count)
                if count > 0 {
                    buffer.append(contentsOf: bytes.prefix(count))
                    guard buffer.count <= 1_048_576 else { throw ProviderError.malformedResponse }
                } else if count == 0 {
                    throw ProviderError.disconnected
                } else if errno != EAGAIN && errno != EINTR {
                    throw ProviderError.disconnected
                } else {
                    try await Task.sleep(for: .milliseconds(20))
                }
            }
        }
        try send(["id": 0, "method": "initialize", "params": ["clientInfo": [
            "name": "codex_meter", "title": "Codex Meter", "version": "1.0"
        ]]])
        _ = try await response(id: 0)
        try send(["method": "initialized", "params": [:]])
        try send(["id": 1, "method": "account/read", "params": ["refreshToken": false]])
        let account = try JSONSerialization.jsonObject(with: await response(id: 1)) as? [String: Any]
        guard let details = account?["account"] as? [String: Any],
              details["type"] as? String != "apiKey" else {
            throw ProviderError.notSignedIn
        }
        try send(["id": 2, "method": "account/rateLimits/read"])
        return try decodeSnapshot(await response(id: 2))
    }

    /// Maps app-server quota fields into the existing presentation models.
    static func decodeSnapshot(_ data: Data) throws -> UsageSnapshot {
        let result = try JSONDecoder().decode(RateLimitResult.self, from: data)
        guard let limits = result.rateLimitsByLimitId?["codex"] ?? result.rateLimits else {
            throw ProviderError.malformedResponse
        }
        let windows = UsageSnapshot.classify(primary: limits.primary?.window, secondary: limits.secondary?.window)
        let reset = result.rateLimitResetCredits
        let expiry = reset?.credits?.filter { $0.status == "available" }
            .compactMap(\.expiresAt).min()
        let banked: BankedResetInfo?
        if let reset, reset.availableCount > 0, let expiry {
            banked = BankedResetInfo(availableCount: reset.availableCount, nextExpiry: expiry)
        } else { banked = nil }
        return UsageSnapshot(session: windows.session, weekly: windows.weekly, bankedResetInfo: banked)
    }

    private struct RateLimitResult: Decodable {
        let rateLimits: Limits?
        let rateLimitsByLimitId: [String: Limits]?
        let rateLimitResetCredits: ResetCredits?
    }
    private struct Limits: Decodable {
        let primary: Window?
        let secondary: Window?
    }
    private struct Window: Decodable {
        let usedPercent: Double
        let windowDurationMins: Double?
        let resetsAt: Double?
        var window: UsageWindow {
            UsageWindow(utilization: usedPercent, resetsAt: resetsAt.map(Date.init(timeIntervalSince1970:)),
                        duration: windowDurationMins.map { $0 * 60 })
        }
    }
    private struct ResetCredits: Decodable {
        let availableCount: Int
        let credits: [Credit]?
    }
    private struct Credit: Decodable {
        let status: String
        let expiresAt: Date?
        private enum CodingKeys: String, CodingKey { case status, expiresAt }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            status = try values.decode(String.self, forKey: .status)
            if let seconds = try? values.decode(Double.self, forKey: .expiresAt) {
                expiresAt = Date(timeIntervalSince1970: seconds)
            } else if let text = try? values.decode(String.self, forKey: .expiresAt) {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                expiresAt = formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
            } else { expiresAt = nil }
        }
    }
}
