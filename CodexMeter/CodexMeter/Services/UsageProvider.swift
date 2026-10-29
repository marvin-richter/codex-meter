import Foundation

/// Provider of usage snapshots. The protocol exists so future providers
/// (or test fakes) can swap in for `AppServerProvider` without changing the
/// poller. Single concrete impl today.
protocol UsageProvider: Sendable {
    func fetchUsage() async throws -> UsageSnapshot
}
