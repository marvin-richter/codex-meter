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
