import Foundation
import Testing
@testable import CodexMeter

@Suite("Banked reset presentation")
struct BankedResetPresentationTests {
    private let now = Date(timeIntervalSince1970: 1_786_000_000)

    @Test("Uses the verbose countdown convention")
    func verboseCountdown() {
        let info = BankedResetInfo(
            availableCount: 2,
            nextExpiry: now.addingTimeInterval(4 * 86400)
        )

        let status = BankedResetStatus(info: info, now: now)

        #expect(status.countText == "2 Resets Left")
        #expect(status.expiryText == "Next Expiry in 4 days")
        #expect(!status.isExpiringSoon)
    }

    @Test("Uses singular reset copy")
    func singularResetCopy() {
        let info = BankedResetInfo(
            availableCount: 1,
            nextExpiry: now.addingTimeInterval(4 * 86400)
        )

        let status = BankedResetStatus(info: info, now: now)

        #expect(status.countText == "1 Reset Left")
    }

    @Test("Expiry is urgent only below 24 hours")
    func urgentBelowTwentyFourHours() {
        let atThreshold = BankedResetStatus(
            info: BankedResetInfo(
                availableCount: 1,
                nextExpiry: now.addingTimeInterval(24 * 3600)
            ),
            now: now
        )
        let belowThreshold = BankedResetStatus(
            info: BankedResetInfo(
                availableCount: 1,
                nextExpiry: now.addingTimeInterval(24 * 3600 - 1)
            ),
            now: now
        )

        #expect(!atThreshold.isExpiringSoon)
        #expect(belowThreshold.isExpiringSoon)
    }
}

@Suite("UsageSnapshot window availability")
struct UsageSnapshotAvailabilityTests {

    private static func snapshot(session: Double?, weekly: Double?) -> UsageSnapshot {
        UsageSnapshot(
            session: session.map { UsageWindow(utilization: $0, resetsAt: nil, duration: 18000) },
            weekly: weekly.map { UsageWindow(utilization: $0, resetsAt: nil, duration: 604800) }
        )
    }

    @Test("availableWindows lists published windows in display order")
    func availableWindowsOrder() {
        #expect(Self.snapshot(session: 1, weekly: 2).availableWindows == [.session, .weekly])
        #expect(Self.snapshot(session: nil, weekly: 2).availableWindows == [.weekly])
        #expect(Self.snapshot(session: 1, weekly: nil).availableWindows == [.session])
        #expect(Self.snapshot(session: nil, weekly: nil).availableWindows.isEmpty)
    }

    @Test("Preferred window is honored when it's published")
    func resolvesToPreference() {
        let snapshot = Self.snapshot(session: 1, weekly: 2)
        #expect(snapshot.resolvedWindow(preferring: .session) == .session)
        #expect(snapshot.resolvedWindow(preferring: .weekly) == .weekly)
    }

    @Test("Preferring a retired window falls back to the published one")
    func fallsBackWhenPreferredMissing() {
        // The case that matters today: a user whose saved preference is
        // Session, on an API that no longer publishes it.
        let snapshot = Self.snapshot(session: nil, weekly: 2)
        #expect(snapshot.resolvedWindow(preferring: .session) == .weekly)
    }

    @Test("No published windows resolves to nil")
    func resolvesToNilWhenEmpty() {
        #expect(Self.snapshot(session: nil, weekly: nil).resolvedWindow(preferring: .session) == nil)
    }

    @Test("Persisted pre-rename raw values still decode")
    func migratesLegacyRawValues() {
        #expect(TrackedWindow.fromPersisted("fiveHour") == .session)
        #expect(TrackedWindow.fromPersisted("sevenDay") == .weekly)
        #expect(TrackedWindow.fromPersisted("session") == .session)
        #expect(TrackedWindow.fromPersisted("weekly") == .weekly)
        #expect(TrackedWindow.fromPersisted("nonsense") == nil)
    }
}

/// The body observed from `GET /backend-api/wham/usage` on 2026-07-27
/// (PII redacted): session limits retired, the weekly window occupying
/// `primary_window`. Mirrors `assets/fixtures/wham-usage.json`.
private let weeklyOnlyResponse = """
{
  "user_id": "user-XXXXXXXXXXXXXXXXXX",
  "account_id": "user-XXXXXXXXXXXXXXXXXX",
  "email": "user@example.com",
  "plan_type": "prolite",
  "rate_limit": {
    "allowed": true,
    "limit_reached": false,
    "primary_window": {
      "used_percent": 12,
      "limit_window_seconds": 604800,
      "reset_after_seconds": 448085,
      "reset_at": 1785615365
    },
    "secondary_window": null
  },
  "code_review_rate_limit": null,
  "additional_rate_limits": [
    {
      "limit_name": "GPT-5.3-Codex-Spark",
      "metered_feature": "codex_bengalfox",
      "rate_limit": {
        "allowed": true,
        "limit_reached": false,
        "primary_window": {"used_percent": 0, "limit_window_seconds": 604800, "reset_after_seconds": 604800, "reset_at": 1785772080},
        "secondary_window": null
      }
    }
  ],
  "credits": {
    "has_credits": false,
    "unlimited": false,
    "overage_limit_reached": false,
    "balance": "0",
    "approx_local_messages": [0, 0],
    "approx_cloud_messages": [0, 0]
  },
  "spend_control": {"reached": false, "individual_limit": null},
  "rate_limit_reached_type": null,
  "promo": null,
  "rate_limit_reset_credits": {"available_count": 2, "applicable_available_count": 0}
}
"""

/// The body observed on 2026-05-01, back when OpenAI published a 5h
/// session window alongside the weekly one. Kept so the parser stays
/// correct if session limits are reinstated. Mirrors
/// `assets/fixtures/wham-usage-dual-window.json`.
private let dualWindowResponse = """
{
  "user_id": "user-XXXXXXXXXXXXXXXXXX",
  "account_id": "user-XXXXXXXXXXXXXXXXXX",
  "email": "user@example.com",
  "plan_type": "prolite",
  "rate_limit": {
    "allowed": true,
    "limit_reached": false,
    "primary_window": {
      "used_percent": 1,
      "limit_window_seconds": 18000,
      "reset_after_seconds": 12496,
      "reset_at": 1777694872
    },
    "secondary_window": {
      "used_percent": 4,
      "limit_window_seconds": 604800,
      "reset_after_seconds": 301422,
      "reset_at": 1777983799
    }
  },
  "code_review_rate_limit": null,
  "additional_rate_limits": [
    {
      "limit_name": "GPT-5.3-Codex-Spark",
      "metered_feature": "codex_bengalfox",
      "rate_limit": {
        "allowed": true,
        "limit_reached": false,
        "primary_window": {"used_percent": 0, "limit_window_seconds": 18000, "reset_after_seconds": 18000, "reset_at": 1777700377},
        "secondary_window": {"used_percent": 0, "limit_window_seconds": 604800, "reset_after_seconds": 604800, "reset_at": 1778287177}
      }
    }
  ],
  "credits": {
    "has_credits": false,
    "unlimited": false,
    "overage_limit_reached": false,
    "balance": "0",
    "approx_local_messages": [0, 0],
    "approx_cloud_messages": [0, 0]
  },
  "spend_control": {"reached": false, "individual_limit": null},
  "rate_limit_reached_type": null,
  "promo": null,
  "referral_beacon": null
}
"""
