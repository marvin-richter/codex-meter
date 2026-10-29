import Foundation
import Testing
@testable import CodexMeter

struct AppServerProviderTests {
    @Test func classifiesWeeklyPrimaryAndSelectsCodexBucket() throws {
        let data = Data(#"{"rateLimits":{"primary":{"usedPercent":99,"windowDurationMins":300}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":16,"windowDurationMins":10080,"resetsAt":1800000000}}}}"#.utf8)
        let snapshot = try AppServerProvider.decodeSnapshot(data)
        #expect(snapshot.session == nil)
        #expect(snapshot.weekly?.utilization == 16)
        #expect(snapshot.weekly?.duration == 604800)
        #expect(snapshot.weekly?.resetsAt == Date(timeIntervalSince1970: 1800000000))
    }

    @Test func mapsBothWindowsAndEarliestAvailableReset() throws {
        let data = Data(#"{"rateLimits":{"primary":{"usedPercent":6,"windowDurationMins":300},"secondary":{"usedPercent":16,"windowDurationMins":10080}},"rateLimitResetCredits":{"availableCount":2,"credits":[{"status":"used","expiresAt":"2026-01-01T00:00:00Z"},{"status":"available","expiresAt":"2026-12-01T00:00:00.000Z"},{"status":"available","expiresAt":"2026-11-01T00:00:00Z"}]}}"#.utf8)
        let snapshot = try AppServerProvider.decodeSnapshot(data)
        #expect(snapshot.session?.utilization == 6)
        #expect(snapshot.weekly?.utilization == 16)
        #expect(snapshot.bankedResetInfo?.availableCount == 2)
        #expect(snapshot.bankedResetInfo?.nextExpiry == ISO8601DateFormatter().date(from: "2026-11-01T00:00:00Z"))
    }

    @Test func numericResetExpiry() throws {
        let data = Data(#"{"rateLimits":{},"rateLimitResetCredits":{"availableCount":1,"credits":[{"status":"available","expiresAt":1800000000}]}}"#.utf8)
        #expect(try AppServerProvider.decodeSnapshot(data).bankedResetInfo?.nextExpiry == Date(timeIntervalSince1970: 1800000000))
    }

    @Test func countWithoutDetailsDoesNotInventExpiry() throws {
        let data = Data(#"{"rateLimits":{},"rateLimitResetCredits":{"availableCount":2,"credits":null}}"#.utf8)
        #expect(try AppServerProvider.decodeSnapshot(data).bankedResetInfo == nil)
    }

    @Test func missingQuotaEnvelopeFails() {
        #expect(throws: (any Error).self) {
            try AppServerProvider.decodeSnapshot(Data("{}".utf8))
        }
    }
}

struct WindowClassificationTests {
    @Test func placesSwappedWindowsByDuration() {
        let weekly = UsageWindow(utilization: 40, resetsAt: nil, duration: 604800)
        let session = UsageWindow(utilization: 10, resetsAt: nil, duration: 18000)
        let result = UsageSnapshot.classify(primary: weekly, secondary: session)
        #expect(result.session == session)
        #expect(result.weekly == weekly)
    }
    @Test func missingDurationsUsePositionalFallback() {
        let primary = UsageWindow(utilization: 10, resetsAt: nil)
        let secondary = UsageWindow(utilization: 40, resetsAt: nil)
        let result = UsageSnapshot.classify(primary: primary, secondary: secondary)
        #expect(result.session == primary)
        #expect(result.weekly == secondary)
    }
}

struct AppServerProcessTests {
    private func withScript(_ body: String, test: (URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = directory.appendingPathComponent("codex")
        try Data(("#!/bin/sh\n" + body + "\n").utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        try await test(script)
    }

    @Test func stalledChildTimesOut() async throws {
        try await withScript("exec /bin/sleep 60") { executable in
            let provider = AppServerProvider(executable: executable, timeout: .milliseconds(100))
            do {
                _ = try await provider.fetchUsage()
                Issue.record("Expected timeout")
            } catch AppServerProvider.ProviderError.timedOut { }
        }
    }

    @Test func childExitIsReported() async throws {
        try await withScript("exit 0") { executable in
            let provider = AppServerProvider(executable: executable)
            await #expect(throws: (any Error).self) { try await provider.fetchUsage() }
        }
    }

    @Test func cancellingStalledChildReturnsPromptly() async throws {
        try await withScript("exec /bin/sleep 60") { executable in
            let provider = AppServerProvider(executable: executable)
            let task = Task { try await provider.fetchUsage() }
            try await Task.sleep(for: .milliseconds(50))
            task.cancel()
            do {
                _ = try await task.value
                Issue.record("Expected cancellation")
            } catch is CancellationError { }
        }
    }
}
