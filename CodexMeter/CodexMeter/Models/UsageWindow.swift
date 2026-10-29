import Foundation

/// One quota window reported by Codex app-server.
struct UsageWindow: Equatable, Sendable {
    /// Used percentage; views clamp values at their display boundaries.
    let utilization: Double
    let resetsAt: Date?
    /// Total window length in seconds; nil when the CLI omits it.
    let duration: TimeInterval?

    init(utilization: Double, resetsAt: Date?, duration: TimeInterval? = nil) {
        self.utilization = utilization
        self.resetsAt = resetsAt
        self.duration = duration
    }
}
