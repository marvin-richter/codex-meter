import Foundation

/// Drives `UsageStore` with periodic API calls. Owns its task lifecycle.
///
/// Polls every 60 seconds in all UI states. Refresh is the only out-of-band
/// poll; failures use exponential backoff capped at five minutes.
actor UsagePoller {
    private let store: UsageStore
    private let provider: any UsageProvider
    private let interval: TimeInterval
    private let backoffCeiling: TimeInterval

    private var task: Task<Void, Never>?
    private var consecutiveFailures: Int = 0
    init(
        store: UsageStore,
        provider: any UsageProvider,
        interval: TimeInterval = 60,
        backoffCeiling: TimeInterval = 300
    ) {
        self.store = store
        self.provider = provider
        self.interval = interval
        self.backoffCeiling = backoffCeiling
    }

    func start() {
        guard task == nil else { return }
        task = Task(priority: .background) { [weak self] in
            await self?.runLoop()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Force an out-of-band poll (e.g. user clicks "Refresh"). Resets the
    /// next-tick timer is *not* the caller's job — the running loop's sleep
    /// is unaffected, but the snapshot updates immediately.
    func refreshNow() async {
        await pollOnce()
    }

    // Exposed for tests; computes the next sleep interval given current state.
    func nextInterval() -> TimeInterval {
        guard consecutiveFailures > 0 else { return interval }
        let backoff = interval * pow(2.0, Double(consecutiveFailures - 1))
        return min(backoff, backoffCeiling)
    }

    private func runLoop() async {
        while !Task.isCancelled {
            await pollOnce()
            let seconds = nextInterval()
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    }

    private func pollOnce() async {
        do {
            let snapshot = try await provider.fetchUsage()
            await store.updateSnapshot(snapshot)
            consecutiveFailures = 0
        } catch is CancellationError {
            return
        } catch let err as AppServerProvider.ProviderError {
            await store.recordError(.appServer(err))
            consecutiveFailures += 1
        } catch {
            await store.recordError(.unexpected)
            consecutiveFailures += 1
        }
    }
}
